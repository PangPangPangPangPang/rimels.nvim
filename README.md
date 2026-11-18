# rimels.nvim

Type Chinese directly inside Neovim. A thin wrapper around
[rime-ls](https://github.com/wlh320/rime-ls) (the [Rime](https://rime.im) input method
engine exposed as an LSP server) with first-class [blink.cmp](https://github.com/saghen/blink.cmp)
integration: pinyin candidates show up in your normal completion menu, digits commit
candidates like a real IME, and everything is a no-op while toggled off.

## Features

- Toggle Chinese input per session with `:RimeToggle` (state in `vim.g.rime_enabled`)
- Candidates rendered by blink.cmp; `1`-`9` commits the corresponding candidate,
  `<space>` commits the first one, `-` / `=` page through candidates
- Attaches to all buffers but stays dormant until toggled — zero noise in English editing
- Any Rime schema works (e.g. [rime-ice / 雾凇拼音](https://github.com/iDvel/rime-ice))
- `:checkhealth rimels`

## Requirements

- Neovim **0.11+** (`vim.lsp.config` / `vim.lsp.enable`)
- [blink.cmp](https://github.com/saghen/blink.cmp) (tested with v1.10)
- The `rime_ls` binary and a Rime schema (see below)

## Install the rime_ls binary and a schema

On macOS just run `:RimeInstall` (or set `install = { auto = true }` to do it on first
start). It installs whatever is missing — `librime` via Homebrew, the `rime_ls` binary and
the rime-ice schema — then restarts rime_ls. Manual steps, for macOS (Apple Silicon or
Intel) or if you prefer to do it yourself:

```sh
# 1. librime (the prebuilt rime_ls links it dynamically)
brew install librime

# 2. rime_ls prebuilt binary
mkdir -p ~/.local/bin
curl -L https://github.com/wlh320/rime-ls/releases/download/v0.4.3/rime-ls-v0.4.3-universal2-apple-darwin.tar.bz2 | tar xj -C ~/.local/bin
chmod +x ~/.local/bin/rime_ls
xattr -d com.apple.quarantine ~/.local/bin/rime_ls

# 3. a schema as the user data dir — rime-ice (full pinyin) recommended
git clone --depth 1 https://github.com/iDvel/rime-ice ~/.local/share/rime-ls
```

The user data dir is deliberately separate from Squirrel's `~/Library/Rime`, so tweaking
the in-editor schema never touches your system IME. On first start rime-ls deploys the
schema (a `build/` directory appears); the first completion may take a moment.

## Setup

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "PangPangPangPangPang/rimels.nvim",
  event = "VeryLazy",
  keys = {
    { "<c-x>", function() require("rimels").toggle() end, mode = { "n", "i" }, desc = "Toggle Rime" },
  },
  opts = {},
}
```

Then wire the two blink.cmp hooks into your blink config:

```lua
{
  "saghen/blink.cmp",
  opts = {
    keymap = {
      -- commit the first Chinese candidate with <space>; falls back when rime is off
      ["<space>"] = {
        function(cmp)
          return require("rimels.blink").accept_first(cmp)
        end,
        "fallback",
      },
    },
    sources = {
      providers = {
        lsp = {
          -- demote snippets while typing Chinese so pinyin candidates stay on top
          transform_items = function(ctx, items)
            return require("rimels.blink").transform_items(ctx, items)
          end,
        },
      },
    },
  },
}
```

## Default options

```lua
require("rimels").setup({
  cmd = { vim.fn.expand("~/.local/bin/rime_ls") },
  -- environment for the server process; nil auto-detects the librime dylib dir
  -- (/opt/homebrew/lib or /usr/local/lib) on macOS
  cmd_env = nil,
  -- nil = attach to all buffers (recommended: comments, commit messages, markdown, …)
  filetypes = nil,
  -- forwarded to rime_ls, see https://github.com/wlh320/rime-ls#配置
  init_options = {
    enabled = false, -- dormant until :RimeToggle
    shared_data_dir = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport",
    user_data_dir = vim.fn.expand("~/.local/share/rime-ls"),
    log_dir = vim.fn.expand("~/.local/share/rime-ls/log"),
    max_candidates = 9,
    trigger_characters = {},
    schema_trigger_character = "&", -- type & to switch schema mid-input
    paging_characters = { "-", "=" }, -- keep , . free for Chinese punctuation
    long_filter_text = true, -- required for blink.cmp's fuzzy matcher
    show_order_in_label = true,
  },
  digit_accept = true, -- typing 1-9 commits the corresponding candidate
  install = {
    auto = false, -- run :RimeInstall on startup when something is missing
    version = "v0.4.3", -- rime_ls release
    schema_repo = "https://github.com/iDvel/rime-ice",
  },
  -- popup shown after toggling Chinese input
  notify = {
    enabled = true,
    style = "popup", -- "popup" (floating window at cursor) or "notify" (vim.notify)
    timeout = 1000, -- ms
    border = "rounded",
    messages = { on = "中文", off = "English" },
  },
})
```

## API

| Function | Purpose |
|---|---|
| `require("rimels").toggle()` | Toggle Chinese input (also `:RimeToggle`) |
| `require("rimels").enabled()` | Current state, for statuslines |
| `require("rimels").sync()` | Sync user dictionary (also `:RimeSync`) |
| `require("rimels.blink").accept_first(cmp)` | blink keymap action: commit first candidate |
| `require("rimels.blink").transform_items(ctx, items)` | blink LSP provider hook |

Statusline example (lualine):

```lua
{ function() return require("rimels").enabled() and "ㄓ" or "" end }
```

## FAQ

**`Library not loaded: @rpath/librime.1.dylib`** — the prebuilt binary needs librime:
`brew install librime`. The plugin auto-sets `DYLD_LIBRARY_PATH` when it finds the dylib
in `/opt/homebrew/lib` or `/usr/local/lib`; for other locations pass
`cmd_env = { DYLD_LIBRARY_PATH = "/path/to/lib" }`.

**Candidates never appear** — make sure `long_filter_text = true` is still set (blink.cmp
filters candidates against the typed keyword; Chinese labels only survive via the long
filter text) and check `:checkhealth rimels`.

**Using a system IME switcher (im-select.nvim etc.)** — keep it; it complements this
plugin by forcing the *system* IME to English so raw keystrokes reach Neovim. Just don't
let it restore a system Chinese IME on `InsertEnter`.

## License

MIT
