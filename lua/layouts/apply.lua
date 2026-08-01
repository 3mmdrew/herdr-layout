local cli = require("layouts.cli")

local M = {}

local DEFAULT_WAIT_TIMEOUT = 30000

local function log(msg, ...)
  io.stdout:write(msg:format(...), "\n")
end

local function expand(path)
  if path and path:sub(1, 1) == "~" then
    return (os.getenv("HOME") or "~") .. path:sub(2)
  end
  return path
end

-- Returns workspace_id of the workspace labeled `label`, or nil.
local function find_workspace(label)
  local out = cli.capture({ "workspace", "list" })
  local arr = out:match('"workspaces"%s*:%s*(%b[])') or ""
  for obj in arr:gmatch("%b{}") do
    if cli.json_field(obj, nil, "label") == label then
      return cli.json_field(obj, nil, "workspace_id")
    end
  end
  return nil
end

local function create_tab(cfg, tab, ti, workspace_id)
  local label = tab.label or tostring(ti)
  local cwd = expand(tab.cwd or cfg.root)
  local args = { "tab", "create", "--workspace", workspace_id,
    "--label", label, "--no-focus" }
  if cwd then
    args[#args + 1] = "--cwd"
    args[#args + 1] = cwd
  end
  local out = cli.capture(args)
  return cli.json_field(out, "root_pane", "pane_id")
end

local function wait_for(w, pane_ids, tab_no)
  local target = pane_ids[w.pane]
  local timeout = tostring(w.timeout or DEFAULT_WAIT_TIMEOUT)
  log("  waiting for %q in tab %d pane %d (timeout %sms)",
    w.match, tab_no, w.pane, timeout)
  local ok, err = pcall(cli.capture, { "wait", "output", target,
    "--match", w.match, "--timeout", timeout })
  if not ok then
    -- pane read prints plain text (unlike the other subcommands).
    local tail = ""
    pcall(function()
      local out = cli.capture({ "pane", "read", target, "--source", "recent" })
      local lines = {}
      for line in (out .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
      end
      local from = math.max(1, #lines - 9)
      tail = table.concat(lines, "\n", from, #lines)
    end)
    error(("wait_for %q did not match in pane %s.\nLast pane output:\n%s\n(%s)")
      :format(w.match, target, tail, tostring(err)), 0)
  end
end

local function build_tab(cfg, tab, ti, workspace_id, first_pane_id)
  local pane_ids = {}
  for pi, pane in ipairs(tab.panes) do
    if pi == 1 then
      pane_ids[1] = first_pane_id
    else
      local args = { "pane", "split", pane_ids[pi - 1],
        "--direction", pane.split, "--no-focus" }
      if pane.ratio then
        args[#args + 1] = "--ratio"
        args[#args + 1] = tostring(pane.ratio)
      end
      local cwd = expand(pane.cwd or tab.cwd or cfg.root)
      if cwd then
        args[#args + 1] = "--cwd"
        args[#args + 1] = cwd
      end
      local out = cli.capture(args)
      pane_ids[pi] = cli.json_field(out, "pane", "pane_id")
      log("  pane %d:%d created (%s)", ti, pi, pane_ids[pi])
    end
    if pane.wait_for then
      wait_for(pane.wait_for, pane_ids, ti)
    end
    if pane.cmd then
      cli.capture({ "pane", "run", pane_ids[pi], pane.cmd })
      log("  pane %d:%d running: %s", ti, pi, pane.cmd)
    end
  end
end

local function build(cfg, name, workspace_id, first_tab_id, first_pane_id)
  for ti, tab in ipairs(cfg.tabs) do
    local pane_id
    if ti == 1 then
      -- Reuse the tab that workspace create made.
      if tab.label then
        cli.capture({ "tab", "rename", first_tab_id, tab.label })
      end
      pane_id = first_pane_id
    else
      pane_id = create_tab(cfg, tab, ti, workspace_id)
    end
    log("tab %d '%s' ready", ti, tab.label or tostring(ti))
    build_tab(cfg, tab, ti, workspace_id, pane_id)
  end
  cli.capture({ "workspace", "focus", workspace_id })
  log("layout '%s' applied (workspace %s)", name, workspace_id)
end

function M.run(cfg, opts)
  local name = opts.name or cfg.name

  local existing = find_workspace(name)
  if existing then
    if opts.force then
      log("closing existing workspace '%s' (%s)", name, existing)
      cli.capture({ "workspace", "close", existing })
    else
      cli.capture({ "workspace", "focus", existing })
      log("layout '%s' already running (workspace %s), focused", name, existing)
      return
    end
  end

  local args = { "workspace", "create", "--label", name, "--no-focus" }
  local root = expand(cfg.root)
  if root then
    args[#args + 1] = "--cwd"
    args[#args + 1] = root
  end
  local out = cli.capture(args)
  local workspace_id = cli.json_field(out, "workspace", "workspace_id")
  local first_tab_id = cli.json_field(out, "tab", "tab_id")
  local first_pane_id = cli.json_field(out, "root_pane", "pane_id")
  if not (workspace_id and first_tab_id and first_pane_id) then
    error("unexpected workspace create response:\n" .. out, 0)
  end
  log("workspace '%s' created (%s)", name, workspace_id)

  local ok, err = pcall(build, cfg, name, workspace_id, first_tab_id, first_pane_id)
  if not ok then
    io.stderr:write("apply failed, rolling back workspace " .. workspace_id .. "\n")
    pcall(cli.capture, { "workspace", "close", workspace_id })
    error(err, 0)
  end
end

return M
