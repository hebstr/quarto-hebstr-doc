local({
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    return(invisible(NULL))
  }

  dir <- NULL
  for (i in rev(seq_len(sys.nframe()))) {
    ofile <- sys.frame(i)$ofile
    if (is.character(ofile)) {
      dir <- dirname(normalizePath(ofile))
      break
    }
  }
  if (is.null(dir)) {
    stop("register.R needs the path source() records: sys.source() and Rscript set none")
  }

  face <- \(file) file.path(dir, file)

  register_missing <- \(family, ...) {
    known <- c(
      systemfonts::system_fonts()$family,
      systemfonts::registry_fonts()$family
    )
    if (!family %in% known) {
      systemfonts::register_font(family, ...)
    }
  }

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

  ### WEB FONTS ------------------------------------------------------------------

  if (
    !requireNamespace("knitr", quietly = TRUE) ||
      !requireNamespace("svglite", quietly = TRUE)
  ) {
    return(invisible(NULL))
  }

  data_uri <- \(file) {
    paste0("data:font/woff2;base64,", xfun::base64_encode(face(file)))
  }

  web_face <- \(family, file, weight) {
    svglite::font_face(
      family = family,
      woff2 = data_uri(file),
      weight = weight,
      style = "normal"
    )
  }

  cache <- new.env(parent = emptyenv())

  knitr::opts_hooks$set(
    dev = \(options) {
      if (!identical(options$dev, "svglite")) {
        return(options)
      }

      if (is.null(cache$faces)) {
        cache$faces <- list(
          web_face("Luciole", "Luciole-Regular.woff2", 400),
          web_face("Luciole", "Luciole-Bold.woff2", 700)
        )
      }

      current <- options$dev.args
      if (!is.list(current)) {
        current <- list()
      }

      options$dev.args <- utils::modifyList(current, list(web_fonts = cache$faces))
      options
    }
  )

  invisible(NULL)
})
