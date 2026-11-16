local LIGHT_SUFFIX = "-light.svg"
local DARK_SUFFIX = "-dark.svg"
local LIGHT_CLASS = "light-content"
local DARK_CLASS = "dark-content"

local function is_local(src)
  return not src:match("^%a[%w+.-]*:")
end

local function exists(path)
  local handle = io.open(path, "rb")
  if handle == nil then
    return false
  end
  handle:close()
  return true
end

local function roots()
  local list = {}
  local input = quarto.doc.input_file
  if input ~= nil and input ~= "" then
    list[#list + 1] = pandoc.path.directory(input)
  end
  local project = quarto.project and quarto.project.directory
  if project ~= nil and project ~= "" then
    list[#list + 1] = project
  end
  return list
end

local function twin_exists(src)
  if pandoc.path.is_absolute(src) then
    return exists(src)
  end
  for _, root in ipairs(roots()) do
    if exists(pandoc.path.join({ root, src })) then
      return true
    end
  end
  return false
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
  if not twin_exists(dark_src) then
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
