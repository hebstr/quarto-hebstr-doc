local({
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    return(invisible(NULL))
  }

  dir <- NULL
  for (i in rev(seq_len(sys.nframe()))) {
    ofile <- sys.frame(i)$ofile
    if (!is.null(ofile)) {
      dir <- dirname(normalizePath(ofile))
      break
    }
  }
  if (is.null(dir)) {
    stop("register.R must be sourced, not run standalone")
  }

  face <- \(file) file.path(dir, file)

  register_missing <- \(family, ...) {
    installed <- systemfonts::system_fonts()$family
    if (!family %in% installed) {
      systemfonts::register_font(family, ...)
    }
  }

  # WOFF over WOFF2: FreeType decodes WOFF with zlib, WOFF2 only where brotli is compiled in
  register_missing(
    "Luciole",
    plain = face("Luciole-Regular.woff"),
    bold = face("Luciole-Bold.woff"),
    italic = face("Luciole-Italic.woff"),
    bolditalic = face("Luciole-BoldItalic.woff")
  )

  register_missing(
    "Fira Code",
    plain = face("FiraCode-Medium.woff"),
    bold = face("FiraCode-Bold.woff")
  )

  invisible(NULL)
})
