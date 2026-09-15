# Asserts the invariants a DOCX rendered through hebstr-doc-docx owes its
# readers, read off the produced file rather than off template.dotx: that is
# what a consumer receives, and it covers styles, geometry and media at once.
# None of these failures stops a render, and LibreOffice converts every one of
# them without a warning, so this is the only place they surface.
#
# Usage: Rscript scripts/check-docx.R <file.docx>

library(xml2)

text_width_in <- 6.2958
tolerance_in <- 5e-4

ns <- c(
  w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
  rel = "http://schemas.openxmlformats.org/package/2006/relationships"
)
ns_r <- "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

report <- \(ok, label, detail = character()) {
  cat(if (ok) "ok    " else "FAIL  ", label, "\n", sep = "")
  if (!ok && length(detail)) {
    cat(paste0("      ", detail, "\n"), sep = "")
  }
  ok
}

content_parts <- \(dir) {
  list.files(
    file.path(dir, "word"),
    pattern = "^(document|footnotes|endnotes|comments|header[0-9]*|footer[0-9]*)\\.xml$",
    full.names = TRUE
  )
}

check_styles <- \(dir) {
  styles <- read_xml(file.path(dir, "word", "styles.xml"))
  defined <- xml_attr(xml_find_all(styles, "//w:style", ns), "w:styleId", ns)

  missing <- unlist(lapply(content_parts(dir), \(part) {
    refs <- xml_find_all(
      read_xml(part),
      "//w:pStyle | //w:rStyle | //w:tblStyle",
      ns
    )
    values <- xml_attr(refs, "w:val", ns)
    values[!values %in% defined]
  }))
  counts <- table(missing)

  report(
    !length(missing),
    "every w:pStyle, w:rStyle and w:tblStyle resolves to a defined style",
    paste0(names(counts), " (", counts, " references)")
  )
}

check_cells <- \(dir) {
  doc <- read_xml(file.path(dir, "word", "document.xml"))
  cells <- xml_find_all(doc, "//w:tc", ns)

  open <- vapply(
    cells,
    \(tc) {
      blocks <- xml_find_all(tc, "./w:p | ./w:tbl", ns)
      length(blocks) > 0 && xml_name(blocks[[length(blocks)]]) == "tbl"
    },
    logical(1)
  )

  report(
    !any(open),
    "every w:tc ends on a w:p",
    paste(
      sum(open),
      "of",
      length(cells),
      "cells end on a table, which Word refuses to open"
    )
  )
}

check_media <- \(dir) {
  word <- file.path(dir, "word")
  rels_files <- list.files(
    file.path(word, "_rels"),
    pattern = "\\.rels$",
    full.names = TRUE
  )

  referenced <- unlist(lapply(rels_files, \(rels_file) {
    source <- file.path(word, sub("\\.rels$", "", basename(rels_file)))
    if (!file.exists(source)) {
      return(character())
    }
    used <- xml_text(xml_find_all(
      read_xml(source),
      sprintf("//@*[namespace-uri() = '%s']", ns_r)
    ))
    rels <- xml_find_all(read_xml(rels_file), "//rel:Relationship", ns)
    targets <- xml_attr(rels, "Target")[xml_attr(rels, "Id") %in% used]
    normalizePath(file.path(word, targets), mustWork = FALSE)
  }))

  embedded <- normalizePath(
    list.files(file.path(word, c("media", "embeddings")), full.names = TRUE),
    mustWork = FALSE
  )
  dead <- setdiff(embedded, referenced)

  report(
    !length(dead),
    "every file under word/media and word/embeddings is referenced by its part",
    paste(
      length(dead),
      "unreferenced, totalling",
      format(sum(file.size(dead)), big.mark = " "),
      "bytes:",
      paste(basename(dead), collapse = ", ")
    )
  )
}

check_geometry <- \(path) {
  dim <- officer::docx_dim(officer::read_docx(path))
  width <- if (length(dim$page) && length(dim$margins)) {
    unname(dim$page[["width"]] - dim$margins[["left"]] - dim$margins[["right"]])
  } else {
    NA_real_
  }

  report(
    !is.na(width) && abs(width - text_width_in) < tolerance_in,
    sprintf(
      "text width is %s in, the contract hebstr::docx_page_width() reads",
      text_width_in
    ),
    if (is.na(width)) {
      "no page size or margins in the section properties"
    } else {
      sprintf("measured %.4f in", width)
    }
  )
}

check_hyphenation <- \(dir) {
  settings <- read_xml(file.path(dir, "word", "settings.xml"))
  node <- xml_find_first(settings, "//w:autoHyphenation", ns)
  value <- xml_attr(node, "w:val", ns)

  report(
    !inherits(node, "xml_missing") &&
      (is.na(value) || value %in% c("true", "1", "on")),
    "w:autoHyphenation is on, the body being justified",
    "absent or off in word/settings.xml"
  )
}

check_fonts <- \(dir) {
  fonts <- read_xml(file.path(dir, "word", "fontTable.xml"))
  alt <- xml_attr(
    xml_find_all(fonts, "//w:font[@w:name = 'Aptos']/w:altName", ns),
    "w:val",
    ns
  )

  report(
    identical(alt, "Calibri"),
    "Aptos declares Calibri as its w:altName, for Word before 2024",
    if (length(alt)) {
      paste("altName is", alt)
    } else {
      "no Aptos entry, or no altName on it"
    }
  )
}

main <- \(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 1L || !file.exists(args[[1]])) {
    cat("usage: Rscript scripts/check-docx.R <file.docx>\n", file = stderr())
    return(2L)
  }

  dir <- tempfile("check-docx-")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  utils::unzip(args[[1]], exdir = dir)

  results <- c(
    check_styles(dir),
    check_cells(dir),
    check_media(dir),
    check_geometry(args[[1]]),
    check_hyphenation(dir),
    check_fonts(dir)
  )

  if (all(results)) 0L else 1L
}

quit(status = main())
