local M = {}

local function notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = "rimels" })
  end)
end

local function sh(script, cb)
  vim.system({ "sh", "-c", script }, { text = true }, function(res)
    vim.schedule(function()
      cb(res.code == 0, vim.trim((res.stderr or "") .. (res.stdout or "")))
    end)
  end)
end

local function librime_dir()
  for _, dir in ipairs({ "/opt/homebrew/lib", "/usr/local/lib" }) do
    if vim.uv.fs_stat(dir .. "/librime.1.dylib") then
      return dir
    end
  end
end

--- What is missing, as an ordered list of step names.
function M.missing(opts)
  local missing = {}
  if vim.fn.has("mac") == 1 and not librime_dir() then
    table.insert(missing, "librime")
  end
  if vim.fn.executable(opts.cmd[1]) ~= 1 then
    table.insert(missing, "binary")
  end
  if not vim.uv.fs_stat(opts.init_options.user_data_dir) then
    table.insert(missing, "schema")
  end
  return missing
end

local steps = {}

function steps.librime(opts, done)
  if vim.fn.executable("brew") ~= 1 then
    return done(false, "Homebrew not found; install librime manually (brew install librime)")
  end
  sh("brew install librime", done)
end

function steps.binary(opts, done)
  local ver = opts.install.version
  local bin = vim.fn.expand(opts.cmd[1])
  local dir = vim.fn.fnamemodify(bin, ":h")
  local url = ("https://github.com/wlh320/rime-ls/releases/download/%s/rime-ls-%s-universal2-apple-darwin.tar.bz2"):format(
    ver,
    ver
  )
  local script = table.concat({
    "set -e",
    "mkdir -p " .. vim.fn.shellescape(dir),
    "curl -fL " .. vim.fn.shellescape(url) .. " | tar xj -C " .. vim.fn.shellescape(dir),
    "chmod +x " .. vim.fn.shellescape(bin),
    "xattr -d com.apple.quarantine " .. vim.fn.shellescape(bin) .. " 2>/dev/null || true",
  }, "\n")
  sh(script, done)
end

function steps.schema(opts, done)
  local dir = vim.fn.expand(opts.init_options.user_data_dir)
  if vim.fn.executable("git") ~= 1 then
    return done(false, "git not found")
  end
  sh(
    ("git clone --depth 1 %s %s"):format(vim.fn.shellescape(opts.install.schema_repo), vim.fn.shellescape(dir)),
    done
  )
end

--- Install whatever is missing (librime, rime_ls binary, schema). Runs async.
function M.run()
  local opts = require("rimels").options
  if not opts then
    return notify("rimels.setup() has not been called", vim.log.levels.WARN)
  end
  if vim.fn.has("mac") ~= 1 then
    return notify(
      "Automatic install only supports macOS; see the README for manual steps",
      vim.log.levels.WARN
    )
  end

  local todo = M.missing(opts)
  if #todo == 0 then
    return notify("Everything is already installed")
  end

  local function finish()
    notify("Install finished, restarting rime_ls")
    vim.lsp.enable("rime_ls", false)
    -- recompute cmd_env now that librime may exist
    require("rimels.lsp").setup(opts)
  end

  local i = 0
  local function next_step()
    i = i + 1
    local name = todo[i]
    if not name then
      return finish()
    end
    notify(("Installing %s (%d/%d)…"):format(name, i, #todo))
    steps[name](opts, function(ok, out)
      if not ok then
        return notify(("Installing %s failed:\n%s"):format(name, out), vim.log.levels.ERROR)
      end
      next_step()
    end)
  end
  next_step()
end

return M
