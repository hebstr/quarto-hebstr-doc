-- Unit tests for the extension's Lua shortcodes.
-- Run from the repo root, under Quarto's bundled pandoc (the version the
-- extension actually executes against):
--   quarto pandoc lua tests/run.lua
-- Fixture and filter paths in the tests are relative to the repo root, so the
-- working directory must be the repo root, not tests/.

local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "tests"
package.path = here .. "/?.lua;" .. package.path

local lu = require("luaunit")
require("test_add_code_files")
require("test_filetree")

os.exit(lu.LuaUnit.run())
