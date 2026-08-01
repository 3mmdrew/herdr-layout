-- Shell-out helpers for the herdr CLI. All herdr subcommands print a single
-- JSON line; extract fields with string.match ; no deps here

local M = {}

M.herdr = os.getenv("HERDR_BIN_PATH") or "herdr"

local function quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function build(args)
  local parts = { quote(M.herdr) }
  for _, a in ipairs(args) do
    parts[#parts + 1] = quote(a)
  end
  return table.concat(parts, " ")
end

-- Run a herdr command, return trimmed stdout. Errors on nonzero exit.
function M.capture(args)
  local cmd = build(args)
  local f = assert(io.popen(cmd .. " 2>&1"))
  local out = f:read("*a") or ""
  local ok, _, code = f:close()
  if not ok then
    error(("herdr command failed (exit %s):\n  %s\n%s")
      :format(tostring(code), cmd, out), 0)
  end
  return (out:gsub("%s+$", ""))
end

-- Extract "field":"value" from a herdr JSON response, scoped to the first
-- occurrence of an enclosing "object": { ... } key when given.
function M.json_field(json, object, field)
  local scope = json
  if object then
    scope = json:match('"' .. object .. '"%s*:%s*(%b{})')
    if not scope then return nil end
  end
  return scope:match('"' .. field .. '"%s*:%s*"([^"]*)"')
end

return M
