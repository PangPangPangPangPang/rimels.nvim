local M = {}

local defaults = {
  -- path to the rime_ls executable
  cmd = { vim.fn.expand("~/.local/bin/rime_ls") },
  -- extra environment for the server process; nil = auto-detect librime dylib dir on macOS
  cmd_env = nil,
  -- filetypes to attach to; nil = attach to all buffers
  filetypes = nil,
  -- passed to rime_ls verbatim, see https://github.com/wlh320/rime-ls
  init_options = {
    enabled = false,
    shared_data_dir = "/Library/Input Methods/Squirrel.app/Contents/SharedSupport",
    user_data_dir = vim.fn.expand("~/.local/share/rime-ls"),
    log_dir = vim.fn.expand("~/.local/share/rime-ls/log"),
    max_candidates = 9,
    trigger_characters = {},
    schema_trigger_character = "&",
    paging_characters = { "-", "=" },
    long_filter_text = true,
    show_order_in_label = true,
  },
  -- accept a candidate by typing its digit (1-9) directly
  digit_accept = true,
  -- :RimeInstall fetches librime (brew), the rime_ls binary and a schema (macOS only)
  install = {
    -- run :RimeInstall automatically on startup when something is missing
    auto = false,
    version = "v0.4.3",
    schema_repo = "https://github.com/iDvel/rime-ice",
  },
  -- feedback shown after toggling Chinese input
  notify = {
    enabled = true,
    -- "popup": floating window near the cursor; "notify": vim.notify
    style = "popup",
    timeout = 1000, -- ms
    border = "rounded",
    messages = { on = "中文", off = "English" },
  },
}

M.options = nil

local function get_client()
  return vim.lsp.get_clients({ name = "rime_ls" })[1]
end

local function execute_command(command, on_result)
  local client = get_client()
  if not client then
    vim.notify("rime_ls is not attached to any buffer", vim.log.levels.WARN, { title = "rimels" })
    return
  end
  client:request("workspace/executeCommand", { command = command }, function(err, result)
    if err then
      vim.notify(command .. " failed: " .. err.message, vim.log.levels.ERROR, { title = "rimels" })
      return
    end
    if on_result then
      on_result(result)
    end
  end)
end

--- Toggle Chinese input on/off. The state is kept in vim.g.rime_enabled.
function M.toggle()
  execute_command("rime-ls.toggle-rime", function(result)
    -- the server answers null instead of false when toggling off
    vim.g.rime_enabled = result == true

    local n = M.options and M.options.notify
    if n and n.enabled then
      local text = vim.g.rime_enabled and n.messages.on or n.messages.off
      if n.style == "notify" then
        vim.notify(text, vim.log.levels.INFO, { title = "rimels" })
      else
        require("rimels.popup").show(text, { timeout = n.timeout, border = n.border })
      end
    end
  end)
end

--- Sync rime user data (user dictionary, custom phrases).
function M.sync()
  execute_command("rime-ls.sync-user-data")
end

--- Whether Chinese input is currently enabled. Useful for statusline components.
function M.enabled()
  return vim.g.rime_enabled == true
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", defaults, opts or {})
  vim.g.rime_enabled = M.options.init_options.enabled

  require("rimels.lsp").setup(M.options)
  if M.options.digit_accept then
    require("rimels.blink").setup_digit_accept()
  end

  vim.api.nvim_create_user_command("RimeToggle", M.toggle, { desc = "Toggle rime-ls Chinese input" })
  vim.api.nvim_create_user_command("RimeSync", M.sync, { desc = "Sync rime-ls user data" })
  vim.api.nvim_create_user_command("RimeInstall", function()
    require("rimels.install").run()
  end, { desc = "Install librime, rime_ls and a Rime schema" })

  local missing = require("rimels.install").missing(M.options)
  if #missing > 0 then
    if M.options.install.auto then
      vim.schedule(function()
        require("rimels.install").run()
      end)
    else
      vim.schedule(function()
        vim.notify("Missing: " .. table.concat(missing, ", ") .. ". Run :RimeInstall", vim.log.levels.WARN, {
          title = "rimels",
        })
      end)
    end
  end
end

return M
