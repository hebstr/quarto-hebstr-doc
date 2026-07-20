-- Test helpers for the Quarto shortcodes under _extensions/hebstr-doc/filters.
-- These files are shortcode handlers (`return { name = function(args, kwargs, meta) end }`),
-- not Pandoc document filters, so they are invoked directly rather than through
-- pandoc.utils.run_lua_filter. They read the `quarto` global and PANDOC_SCRIPT_FILE
-- at load time, so both must be set before the file is loaded.

local M = { deps = {}, warnings = {} }

-- Minimal stand-in for the `quarto` global, covering only what the shortcodes
-- touch. `is_format` is driven by opts.formats so a test can select the html-js
-- branch or the plain branch; dependencies and warnings are recorded for asserts.
local function make_quarto(opts)
  return {
    doc = {
      is_format = function(f)
        return (opts.formats or {})[f] or false
      end,
      add_html_dependency = function(dep)
        M.deps[#M.deps + 1] = dep
      end,
    },
    log = {
      warning = function(msg)
        M.warnings[#M.warnings + 1] = msg
      end,
    },
    project = { directory = opts.project_dir },
  }
end

-- Load a shortcode file with its globals in place and a fresh recording state.
function M.load_shortcode(relpath, opts)
  opts = opts or {}
  M.deps, M.warnings = {}, {}
  _G.quarto = make_quarto(opts)
  PANDOC_SCRIPT_FILE = opts.script_file
  return dofile(relpath)
end

-- Positional shortcode arguments: a list whose elements are Inlines, matching
-- how Quarto hands arguments to a handler.
function M.args(...)
  local out = {}
  for _, s in ipairs({ ... }) do
    out[#out + 1] = pandoc.Inlines({ pandoc.Str(s) })
  end
  return out
end

-- Named shortcode arguments: name -> Inlines.
function M.kwargs(tbl)
  local out = {}
  for k, v in pairs(tbl or {}) do
    out[k] = pandoc.Inlines({ pandoc.Str(v) })
  end
  return out
end

return M
