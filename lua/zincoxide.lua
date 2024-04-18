local M = {}

local default_opts = {
  zoxide_cmd = "/usr/bin/zoxide",
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
  vim.print(M.opts)

  local copts = { nargs = "*", bang = true }
  if M.opts.complete then
    copts.complete = M.complete
  end
  vim.api.nvim_create_user_command("Z", M.cd, copts)
end

function M.complete(_, cmdline, _)
  local current_path = vim.fn.getcwd()
  local cmd = { M.opts.zoxide_cmd, "query", "-l", "--exclude=" .. current_path }

  cmd[#cmd + 1] = "--"
  local args = vim.api.nvim_parse_cmd(cmdline, {}).args
  if #args > 1 then
    return
  end
  for _, part in pairs(args) do
    cmd[#cmd + 1] = part
  end
  local zoxide_output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    error(zoxide_output)
  end
  return vim.split(zoxide_output, "\n", { plain = true, trimempty = false })
end

function M.resolve(args)
  local params = args
  if #params == 0 then
    return "~"
  end
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
