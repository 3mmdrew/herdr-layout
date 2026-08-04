<div align="center">

<pre>
┌───┬───────────┬───────┐
│   │           │       │
│   │           │ agent │
├───│   nvim    │       │
│   │           ├───────┤
│   │           │ shell │
└───┴───────────┴───────┘
</pre>

# herdr-layout

Lua-config based workspace layouts for [herdr](https://herdr.dev).


[![Lua](https://img.shields.io/badge/lua-5.4-blue?logo=lua)](https://www.lua.org/)
[![herdr plugin](https://img.shields.io/badge/herdr-plugin-8A2BE2)](https://herdr.dev)
[![version](https://img.shields.io/badge/version-0.1.0-green)](herdr-plugin.toml)
[![license: MIT](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)
[![dependencies](https://img.shields.io/badge/dependencies-none-lightgrey)](#)

</div>

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

## Layout picker

Instead of remembering action ids or layout names, open an interactive
picker from anywhere inside herdr:

```sh
herdr plugin action invoke herdr-layout.pick
```

A popup lists the current project's `.herdr-layout.lua` (if any, marked
with `◆`) plus every named layout; pick one and it applies. With
[fzf](https://github.com/junegunn/fzf) installed you get fuzzy search;
without it the picker falls back to a built-in interactive menu — the
zero-dependency promise holds either way. Both are styled after herdr's
own navigator and use the same keys:

| Key | Action |
|-----|--------|
| type | fuzzy-search (fzf only) |
| `j` / `k` / `↑` / `↓` | move selection |
| `enter` | apply the selected layout |
| `esc` / `q` | close without applying |

Bind it once in `~/.config/herdr/config.toml` and layouts become a single
keystroke from any workspace:

```toml
[[keys.command]]
key = "prefix+a"
type = "plugin_action"
command = "herdr-layout.pick"
description = "pick layout"
```

Any free key works, but note that the obvious mnemonic `prefix+l` is
already taken: herdr binds it to `keys.focus_pane_right` by default, as
part of the vim-style `h/j/k/l` pane navigation. `prefix+a` ("apply") has
no default binding. Reload your config (or restart the client) after
adding it.

(Plugin actions run on the herdr server without a TTY, so the `pick` action
itself can't be interactive — it opens a popup plugin pane, which does get
a TTY, and the picker runs there.)

You can still bind the non-interactive `herdr-layout.apply` action the same
way if you want a key that applies the current project's layout directly.

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

bin/herdr-layout <my-layout>   # apply a named layout
bin/herdr-layout --list        # see what's available
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
| `label` | tab, pane | tab title / pane title |
| `cwd` | tab, pane | working directory override |
| `cmd` | pane | command to run in the pane |
| `split` | pane 2+ | `"right"` or `"down"`, splits the previous pane |
| `ratio` | pane | split ratio, optional |
| `wait_for` | pane | `{ pane = N, match = "text", timeout = ms }` — block until an earlier pane in the same tab prints `match` (default timeout 30s) |

Notes:

- `wait_for.match` is checked against the whole pane, including the echoed
  command line — pick text the watched command does not itself contain.
- Configs are executable Lua. Only apply layout files you trust.
