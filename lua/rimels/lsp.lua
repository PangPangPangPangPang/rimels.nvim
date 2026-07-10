local M = {}

-- The prebuilt rime_ls binary links librime dynamically without an rpath, so on
-- macOS the dylib directory has to be injected via DYLD_LIBRARY_PATH.
local function default_cmd_env()
  if vim.fn.has("mac") ~= 1 then
    return nil
  end
  for _, dir in ipairs({ "/opt/homebrew/lib", "/usr/local/lib" }) do
    if vim.uv.fs_stat(dir .. "/librime.1.dylib") then
      return { DYLD_LIBRARY_PATH = dir }
    end
  end
  return nil
end

function M.setup(opts)
  local capabilities
  local ok, blink = pcall(require, "blink.cmp")
  if ok then
    capabilities = blink.get_lsp_capabilities()
  else
    capabilities = vim.lsp.protocol.make_client_capabilities()
  end

  local config = {
    cmd = opts.cmd,
    cmd_env = opts.cmd_env or default_cmd_env(),
    init_options = opts.init_options,
    capabilities = capabilities,
  }
  if opts.filetypes then
    config.filetypes = opts.filetypes
  end

  vim.lsp.config("rime_ls", config)
  vim.lsp.enable("rime_ls")
end

return M
