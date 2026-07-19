-- Inline svglite figures and remap sentinel colours to CSS custom properties
-- so figure ink and gridlines follow the runtime light/dark theme toggle.
-- Ink sentinel #010101 -> currentColor (inherits the page body colour);
-- grid sentinel #020202 -> var(--caption-color) (muted, defined in both themes).
-- Only inline SVG in the DOM lets page CSS reach into the figure; a base64
-- <img> data URI is isolated, so the file is read and emitted as raw HTML.

local function read_file(path)
  local fh = io.open(path, "r")
  if not fh then
    return nil
  end
  local content = fh:read("*a")
  fh:close()
  return content
end

function Image(img)
  if not img.src:match("%.svg$") then
    return nil
  end
  local svg = read_file(img.src)
  if not svg then
    return nil
  end
  svg = svg:gsub("#010101", "currentColor")
  svg = svg:gsub("#020202", "var(--caption-color)")
  -- Keep the intrinsic pt dimensions (they carry the aspect ratio) and cap the
  -- width; this stays responsive even if an HTML re-serialiser drops viewBox.
  svg = svg:gsub(
    "<svg ",
    "<svg class='hebstr-adaptive-fig' style='max-width:100%%;height:auto' ",
    1
  )
  return pandoc.RawInline("html", svg)
end
