local M = {}

function M.check()
  local health = vim.health
  health.start("rimels")

  if vim.fn.has("nvim-0.11") ~= 1 then
    health.error("Neovim 0.11+ is required (vim.lsp.config / vim.lsp.enable)")
    return
  end

  local opts = require("rimels").options
  if not opts then
    health.warn("rimels.setup() has not been called")
    return
  end

  local bin = opts.cmd[1]
  if vim.fn.executable(bin) == 1 then
    health.ok("rime_ls binary: " .. bin)
  else
    health.error("rime_ls binary not found or not executable: " .. bin, {
      "Run :RimeInstall (macOS), or download a release from https://github.com/wlh320/rime-ls/releases",
      "On macOS also run: xattr -d com.apple.quarantine " .. bin,
    })
  end

  local user_data_dir = opts.init_options.user_data_dir
  if vim.uv.fs_stat(user_data_dir) then
    health.ok("user_data_dir: " .. user_data_dir)
  else
    health.error("user_data_dir does not exist: " .. user_data_dir, {
      "Install a schema, e.g. git clone --depth 1 https://github.com/iDvel/rime-ice " .. user_data_dir,
    })
  end

  local shared_data_dir = opts.init_options.shared_data_dir
  if vim.uv.fs_stat(shared_data_dir) then
    health.ok("shared_data_dir: " .. shared_data_dir)
  else
    health.warn("shared_data_dir does not exist: " .. shared_data_dir)
  end

  if pcall(require, "blink.cmp") then
    health.ok("blink.cmp is available")
    local ok, list = pcall(require, "blink.cmp.completion.list")
    if ok and list.show_emitter ~= nil then
      health.ok("blink.cmp completion list API available (digit-key accept works)")
    else
      health.warn("blink.cmp completion list API not found; digit-key accept is disabled")
    end
  else
    health.warn("blink.cmp not found; candidates will not be displayed")
  end

  local client = vim.lsp.get_clients({ name = "rime_ls" })[1]
  if client then
    health.ok(("rime_ls client running (id %d), rime %s"):format(client.id, vim.g.rime_enabled and "on" or "off"))
  else
    health.info("rime_ls client not running yet (starts when a file is opened)")
  end
end

return M
