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

  register_missing(
    "Luciole",
    plain = face("Luciole-Regular.woff2"),
    bold = face("Luciole-Bold.woff2"),
    italic = face("Luciole-Italic.woff2"),
    bolditalic = face("Luciole-BoldItalic.woff2")
  )

  register_missing(
    "Fira Code",
    plain = face("FiraCode-Medium.woff2"),
    bold = face("FiraCode-Bold.woff2")
  )

  invisible(NULL)
})
