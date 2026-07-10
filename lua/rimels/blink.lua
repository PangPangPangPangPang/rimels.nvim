-- Helpers meant to be referenced from the user's blink.cmp configuration.
-- All of them are no-ops while Chinese input is toggled off.
local M = {}

function M.is_rime_item(item)
  if item == nil or item.source_id ~= "lsp" then
    return false
  end
  local client = vim.lsp.get_client_by_id(item.client_id)
  return client ~= nil and client.name == "rime_ls"
end

-- Only CJK candidates should be committed by <space>/digit keys; rime-ls also
-- emits ASCII items (English words, the raw input echo) that must not be hijacked.
-- Labels may carry a leading order number ("1. 你好") when show_order_in_label is on.
local function is_acceptable(item)
  local label = item.label
  if label == nil then
    return false
  end
  local stripped = label:gsub("^[%d%p%s]+", "")
  return stripped:byte(1) ~= nil and stripped:byte(1) > 127
end

--- Indices of the first `n` acceptable rime candidates in the completion list.
function M.get_n_rime_item_index(n, items)
  local result = {}
  if items == nil then
    local ok, list = pcall(require, "blink.cmp.completion.list")
    if not ok then
      return result
    end
    items = list.items
  end
  if items == nil then
    return result
  end
  for i, item in ipairs(items) do
    if M.is_rime_item(item) and is_acceptable(item) then
      result[#result + 1] = i
      if #result == n then
        break
      end
    end
  end
  return result
end

--- For blink keymaps: accept the first rime candidate, e.g.
---   ["<space>"] = { function(cmp) return require("rimels.blink").accept_first(cmp) end, "fallback" },
function M.accept_first(cmp)
  if not vim.g.rime_enabled then
    return false
  end
  local index = M.get_n_rime_item_index(1)
  if #index ~= 1 then
    return false
  end
  return cmp.accept({ index = index[1] })
end

--- For sources.providers.lsp.transform_items: demote snippets while typing Chinese
--- so pinyin candidates stay on top.
function M.transform_items(_, items)
  if not vim.g.rime_enabled then
    return items
  end
  local snippet = require("blink.cmp.types").CompletionItemKind.Snippet
  for _, item in ipairs(items) do
    if item.kind == snippet then
      item.score_offset = (item.score_offset or 0) - 3
    end
  end
  return items
end

--- Typing a digit narrows the rime candidates down to exactly one — commit it
--- immediately, mimicking the select-by-number behavior of a real IME.
function M.setup_digit_accept()
  local ok, list = pcall(require, "blink.cmp.completion.list")
  if not ok or list.show_emitter == nil then
    vim.schedule(function()
      vim.notify(
        "blink.cmp completion list API not available, digit-key accept disabled",
        vim.log.levels.WARN,
        { title = "rimels" }
      )
    end)
    return
  end
  list.show_emitter:on(function(event)
    if not vim.g.rime_enabled then
      return
    end
    local col = vim.fn.col(".") - 1
    if event.context.line:sub(col, col):match("%d") == nil then
      return
    end
    local index = M.get_n_rime_item_index(2, event.items)
    if #index ~= 1 then
      return
    end
    vim.schedule(function()
      require("blink.cmp").accept({ index = index[1] })
    end)
  end)
end

return M
