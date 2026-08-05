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

  ### WEB FONTS ------------------------------------------------------------------

  if (
    !requireNamespace("knitr", quietly = TRUE) ||
      !requireNamespace("svglite", quietly = TRUE)
  ) {
    return(invisible(NULL))
  }

  # WOFF2 here, unlike the registration above: this string is never parsed by
  # FreeType, it is concatenated into a CSS rule the browser reads
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

  # built on first use, not at source time: encoding the two faces costs ~35 ms
  # that every interactive session would pay through .Rprofile without rendering
  faces <- NULL

  # An opts_chunk$set() here would be overwritten by the format's own dev.args
  # when sourced from .Rprofile, and dropped by any chunk that sets dev.args
  # itself (a chunk value replaces the format value, it does not extend it).
  # A hook runs after option resolution, so it survives both.
  # utils:: qualified: sourced from .Rprofile, no package is attached yet
  knitr::opts_hooks$set(
    dev = \(options) {
      if (!identical(options$dev, "svglite")) {
        return(options)
      }

      if (is.null(faces)) {
        faces <<- list(
          web_face("Luciole", "Luciole-Regular.woff2", 400),
          web_face("Luciole", "Luciole-Bold.woff2", 700)
        )
      }

      current <- options$dev.args
      if (!is.list(current)) {
        current <- list()
      }

      options$dev.args <- utils::modifyList(current, list(web_fonts = faces))
      options
    }
  )

  invisible(NULL)
})
