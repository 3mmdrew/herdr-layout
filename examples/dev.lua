-- Example layout. Apply with:
--   bin/herdr-layout examples/dev.lua
return {
  name = "myproject",
  root = "~/code/myproject", -- default cwd for all tabs and panes
  tabs = {
    {
      label = "server",
      panes = {
        { cmd = "npm run dev" },
        {
          split = "down",
          ratio = 0.3,
          cmd = "npm run worker",
          -- Block until pane 1 prints "Listening" (max 30s).
          -- Note: the match is checked against the whole pane, including
          -- the echoed command line, so pick text the command itself
          -- does not contain.
          wait_for = { pane = 1, match = "Listening", timeout = 30000 },
        },
      },
    },
    {
      label = "editor",
      panes = {
        { cmd = "nvim" },
      },
    },
  },
}
