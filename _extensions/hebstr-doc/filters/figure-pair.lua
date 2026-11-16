local LIGHT_SUFFIX = "-light.svg"
local DARK_SUFFIX = "-dark.svg"
local LIGHT_CLASS = "light-content"
local DARK_CLASS = "dark-content"

local function is_local(src)
  return not src:match("^%a[%w+.-]*:")
end

local function resolve(src)
  if pandoc.path.is_absolute(src) then
    return src
  end
  local input = quarto.doc.input_file
  if input == nil or input == "" then
    return nil
  end
  return pandoc.path.join({ pandoc.path.directory(input), src })
end

local function exists(path)
  local handle = io.open(path, "rb")
  if handle == nil then
    return false
  end
  handle:close()
  return true
end

local function Image(el)
  if el.classes:includes(LIGHT_CLASS) or el.classes:includes(DARK_CLASS) then
    return nil
  end
  local src = el.src
  if #src <= #LIGHT_SUFFIX or src:sub(-#LIGHT_SUFFIX) ~= LIGHT_SUFFIX or not is_local(src) then
    return nil
  end
  local dark_src = src:sub(1, -#LIGHT_SUFFIX - 1) .. DARK_SUFFIX
  local dark_path = resolve(dark_src)
  if dark_path == nil or not exists(dark_path) then
    return nil
  end
  local dark = el:clone()
  dark.src = dark_src
  dark.identifier = ""
  dark.classes = pandoc.List({ DARK_CLASS })
  el.classes:insert(LIGHT_CLASS)
  return { el, dark }
end

return { { Image = Image } }
