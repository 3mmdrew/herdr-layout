local apply = require("layouts.apply")

local M = {}

local TOP_KEYS = { name = true, root = true, tabs = true }
local TAB_KEYS = { label = true, cwd = true, panes = true }
local PANE_KEYS = { cmd = true, split = true, ratio = true, cwd = true, label = true, wait_for = true }
local WAIT_KEYS = { pane = true, match = true, timeout = true }

local function fail(msg, ...)
  error("config error: " .. msg:format(...), 0)
end

local function check_keys(tbl, allowed, where)
  for k in pairs(tbl) do
    if type(k) ~= "number" and not allowed[k] then
      local hint = ""
      for a in pairs(allowed) do
        if a:sub(1, 2) == tostring(k):sub(1, 2) then
          hint = (" (did you mean '%s'?)"):format(a)
          break
        end
      end
      fail("%s: unknown key '%s'%s", where, tostring(k), hint)
    end
  end
end

local function validate(cfg)
  if type(cfg) ~= "table" then
    fail("config file must return a table")
  end
  check_keys(cfg, TOP_KEYS, "top level")
  if type(cfg.name) ~= "string" or cfg.name == "" then
    fail("'name' must be a non-empty string")
  end
  if cfg.root ~= nil and type(cfg.root) ~= "string" then
    fail("'root' must be a string")
  end
  if type(cfg.tabs) ~= "table" or #cfg.tabs == 0 then
    fail("'tabs' must be a non-empty list")
  end
  for ti, tab in ipairs(cfg.tabs) do
    local twhere = ("tab %d"):format(ti)
    if type(tab) ~= "table" then fail("%s: must be a table", twhere) end
    check_keys(tab, TAB_KEYS, twhere)
    if type(tab.panes) ~= "table" or #tab.panes == 0 then
      fail("%s: 'panes' must be a non-empty list", twhere)
    end
    for pi, pane in ipairs(tab.panes) do
      local pwhere = ("%s, pane %d"):format(twhere, pi)
      if type(pane) ~= "table" then fail("%s: must be a table", pwhere) end
      check_keys(pane, PANE_KEYS, pwhere)
      if pi > 1 and pane.split ~= "right" and pane.split ~= "down" then
        fail("%s: 'split' must be 'right' or 'down'", pwhere)
      end
      if pane.wait_for ~= nil then
        local w = pane.wait_for
        check_keys(w, WAIT_KEYS, pwhere .. ", wait_for")
        if type(w.pane) ~= "number" or w.pane < 1 or w.pane >= pi then
          fail("%s: wait_for.pane must be the index of an earlier pane in the same tab", pwhere)
        end
        if type(w.match) ~= "string" or w.match == "" then
          fail("%s: wait_for.match must be a non-empty string", pwhere)
        end
      end
    end
  end
end

-- opts: { name = <label override>, force = <bool> }
function M.apply(config_path, opts)
  opts = opts or {}
  local chunk, err = loadfile(config_path)
  if not chunk then
    error("cannot load config: " .. tostring(err), 0)
  end
  local cfg = chunk()
  validate(cfg)
  apply.run(cfg, opts)
end

return M
