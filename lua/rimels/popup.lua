local M = {}

local state = { win = nil, timer = nil }

local function close()
  if state.timer then
    state.timer:stop()
    if not state.timer:is_closing() then
      state.timer:close()
    end
    state.timer = nil
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

--- Show a short-lived floating window near the cursor.
---@param text string
---@param opts? { timeout?: integer, border?: string|table }
function M.show(text, opts)
  opts = opts or {}
  close()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local line = " " .. text .. " "
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })

  local ok, win = pcall(vim.api.nvim_open_win, buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = vim.fn.strdisplaywidth(line),
    height = 1,
    style = "minimal",
    border = opts.border or "rounded",
    focusable = false,
    noautocmd = true,
    zindex = 250,
  })
  if not ok then
    return
  end
  state.win = win

  local timer = vim.uv.new_timer()
  state.timer = timer
  timer:start(
    opts.timeout or 1000,
    0,
    vim.schedule_wrap(function()
      if state.timer == timer then
        close()
      end
    end)
  )
end

return M
