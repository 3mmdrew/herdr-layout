-- Named layouts live as <name>.lua files in one well-known directory.

local M = {}

M.dir = (os.getenv("HOME") or "~") .. "/.config/herdr/layouts"

function M.names()
  local names = {}
  local f = io.popen("ls -1 '" .. M.dir .. "' 2>/dev/null")
  if f then
    for line in f:lines() do
      local name = line:match("^(.+)%.lua$")
      if name then names[#names + 1] = name end
    end
    f:close()
  end
  return names
end

function M.path(name)
  return M.dir .. "/" .. name .. ".lua"
end

return M
