local M = {}

local default_opts = {
  zoxide_cmd = "zoxide",
  complete = true,
  behaviour = "tabs",
}

function M.setup(opts)
  M.opts = {}
  for _, opt in ipairs({ "zoxide_cmd", "complete", "behaviour" }) do
    if opts[opt] == nil then
      M.opts[opt] = default_opts[opt]
    else
      M.opts[opt] = opts[opt]
    end
  end

  local copts = { nargs = "*", bang = true }
  if M.opts.complete then
    copts.complete = M.complete
  end
  vim.api.nvim_create_user_command("Z", M.cd, copts)
end

function M.complete(_, cmdline, _)
  local current_path = vim.fn.getcwd()
  local cmd = { M.opts.zoxide_cmd, "query", "-l", "--exclude=" .. current_path, "--" }
  local args = vim.api.nvim_parse_cmd(cmdline, {}).args
  local home = os.getenv("HOME") .. "/"
  if #args > 1 then
    return
  end
  local dir_completes = {}
  if #args == 1 then
    local dir_string = args[1]:match(".*/") or "./"
    if home ~= nil and vim.startswith(dir_string, "~/") then
      dir_string = home .. string.sub(dir_string, 3)
    end
    local dir = vim.loop.fs_opendir(dir_string, nil, 1)
    if dir ~= nil then
      while true do
        local entry = vim.loop.fs_readdir(dir)
        if entry == nil then
          break
        end
        if
          entry[1].type == "directory"
          or (entry[1].type == "link" and (vim.loop.fs_opendir(dir_string .. entry[1].name) ~= nil))
        then
          dir_completes[#dir_completes + 1] = dir_string .. entry[1].name
        end
      end
    end
  end
  for _, part in pairs(args) do
    cmd[#cmd + 1] = part
  end
  local zoxide_output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    error(zoxide_output)
  end
  local zoxide_entries = vim.split(zoxide_output, "\n", { plain = true, trimempty = false })
  local completions = {}
  for _, entry in pairs(dir_completes) do
    if home ~= nil and vim.startswith(entry, home) then
      entry = "~/" .. string.sub(entry, #home + 1)
    end
    completions[#completions + 1] = entry
  end
  for _, entry in pairs(zoxide_entries) do
    if home ~= nil and vim.startswith(entry, home) then
      entry = "~/" .. string.sub(entry, #home + 1)
    end
    completions[#completions + 1] = entry
  end
  return completions
end

function M.resolve(args)
  local home = os.getenv("HOME")
  if #args == 0 or (#args == 1 and args[1] == "~") then
    return home
  end
  if #args == 1 then
    if vim.startswith(args[1], "/") or vim.startswith(args[1], "./") then
      return args[1]
    end
    if home ~= nil and vim.startswith(args[1], "~/") then
      args[1] = home .. "/" .. string.sub(args[1], 3)
      goto out
    end
    if vim.loop.fs_opendir(args[1]) ~= nil then
      return vim.loop.fs_realpath(args[1])
    end
  end
  ::out::
  local current_path = vim.fn.getcwd()
  local cmd = { M.opts.zoxide_cmd, "query", "--exclude=" .. current_path }
  cmd[#cmd + 1] = "--"
  for _, part in pairs(args) do
    cmd[#cmd + 1] = part
  end

  local path = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return { path, vim.v.shell_error }
  end
  if string.sub(path, -1, -1) == "\n" then
    path = string.sub(path, 0, -2)
  end
  return path
end

function M.cd(opts)
  local target = M.resolve(opts.fargs)
  if type(target) ~= "string" then
    if opts.bang then
      return
    end
    if target[2] == -1 then
      error("zoxide binary (" .. M.opts.zoxide_cmd .. ") could not be executed")
    elseif target[2] ~= 0 then
      error("zoxide error: '" .. target[1] .. "'")
    end
  end
  -- Increment score
  vim.fn.system({ M.opts.zoxide_cmd, "add", "--", target })
  if M.opts.behaviour == "tabs" then
    vim.cmd("tcd " .. target)
  elseif M.opts.behaviour == "window" then
    vim.cmd("lcd " .. target)
  elseif M.opts.behaviour == "global" then
    vim.cmd("cd " .. target)
  end
end

return M
