<div align="center">

```
┌───┬───────────┬───────┐
│   │           │       │
│   │           │ agent │
├───│   nvim    │       │
│   │           ├───────┤
│   │           │ shell │
└───┴───────────┴───────┘
```

# herdr-layout

[![Lua](https://img.shields.io/badge/lua-5.4-blue?logo=lua)](https://www.lua.org/)
[![herdr plugin](https://img.shields.io/badge/herdr-plugin-8A2BE2)](https://herdr.dev)
[![version](https://img.shields.io/badge/version-0.1.0-green)](herdr-plugin.toml)
[![license: MIT](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)
[![dependencies](https://img.shields.io/badge/dependencies-none-lightgrey)](#)

</div>

Lua-config based workspace layouts for [herdr](https://herdr.dev).

Describe your project's tabs, panes, and startup commands once, in a small
Lua file. Then bring the whole workspace up with one command — or attach to
it if already running.

**Minimalist by design.** No daemon, no state files, no dependencies: the
entire tool is a few hundred lines of Lua that shell out to the herdr CLI.
If you have `lua` on your PATH, you have everything.

Built initially to help me jump quickly between projects and contexts.

## Install

```sh
herdr plugin install 3mmdrew/herdr-layout

# or from a local checkout
herdr plugin link /path/to/herdr-layout
```

The plugin system is optional — the script also runs standalone:

```sh
bin/herdr-layout examples/dev.lua
```

## Quick start

Drop a `.herdr-layout.lua` in your project directory:

```lua
return {
  name = "myproject",
  root = "~/code/myproject",
  tabs = {
    {
      label = "server",
      panes = {
        { cmd = "npm run dev" },
        { split = "down", ratio = 0.3, cmd = "npm run worker",
          wait_for = { pane = 1, match = "Listening" } },
      },
    },
    { label = "editor", panes = { { cmd = "nvim" } } },
  },
}
```

Then, from that directory:

```sh
herdr plugin action invoke herdr-layout.apply
```

herdr opens a workspace named `myproject` with both tabs, splits the server
tab, waits until the dev server prints "Listening", then starts the worker.
Run it again and it simply focuses the existing workspace.

Optional keybinding in `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "prefix+l"
type = "plugin_action"
command = "herdr-layout.apply"
description = "apply layout"
```

## Usage

```
herdr-layout [config.lua | name] [--name LABEL] [--force] [--list]
```

- No argument: uses `.herdr-layout.lua` from the current directory (the
  focused workspace's directory when invoked as a plugin action).
- A path: loads that config file.
- A bare name: loads `~/.config/herdr/layouts/<name>.lua` (see below).
- `--name LABEL`: open a second, independent instance of the same layout
  under a different workspace label.
- `--force`: close the existing workspace with this label and rebuild it.
- `--list`: print the available named layouts and exit.

### Named layouts

Keep layouts you use often in `~/.config/herdr/layouts/`:

```sh
mkdir -p ~/.config/herdr/layouts
cp examples/dev.lua ~/.config/herdr/layouts/<my-layout>.lua

herdr-layout <my-layout>   # from anywhere
herdr-layout --list        # see what's available
```

Tip: symlink `bin/herdr-layout` somewhere on your PATH to invoke named
layouts from any directory:

```sh
ln -s "$(pwd)/bin/herdr-layout" ~/bin/herdr-layout
```

Behavior you can rely on:

- The layout's `name` is its identity. If a workspace with that label
  exists, it is focused, never duplicated.
- If anything fails mid-build, the half-built workspace is closed
  automatically — you never end up with debris.
- Every step is narrated, including what `wait_for` is blocking on; on a
  wait timeout you get the pane's recent output so the mismatch is obvious.

## Config reference

A layout config is a Lua file that returns one table:

| Key | Where | Meaning |
|-----|-------|---------|
| `name` | top | workspace label, required |
| `root` | top | default working directory for everything |
| `label` | tab | tab title |
| `cwd` | tab, pane | working directory override |
| `cmd` | pane | command to run in the pane |
| `split` | pane 2+ | `"right"` or `"down"`, splits the previous pane |
| `ratio` | pane | split ratio, optional |
| `wait_for` | pane | `{ pane = N, match = "text", timeout = ms }` — block until an earlier pane in the same tab prints `match` (default timeout 30s) |

Notes:

- `wait_for.match` is checked against the whole pane, including the echoed
  command line — pick text the watched command does not itself contain.
- Configs are executable Lua. Only apply layout files you trust.
