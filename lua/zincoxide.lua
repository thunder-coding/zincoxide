local M = {}

local default_opts = {
  zoxide_cmd = "zoxide",
  complete = true,
  behaviour = "tabs",
}

function M.setup(opts)
  M.opts = {}

  -- If user has not provided any configuration for the option, use defaults
  for _, opt in ipairs({ "zoxide_cmd", "complete", "behaviour" }) do
    if opts[opt] == nil then
      M.opts[opt] = default_opts[opt]
    else
      M.opts[opt] = opts[opt]
    end
  end

  local copts = { nargs = "*", bang = true }

  -- Only provide completions if opt.complete = true
  if M.opts.complete then
    copts.complete = M.complete
  end

  -- Register the command ':Z'
  vim.api.nvim_create_user_command("Z", function(opts_)
    M.cd(opts_, M.opts.behaviour)
  end, copts)
  vim.api.nvim_create_user_command("Zg", function(opts_)
    M.cd(opts_, "global")
  end, copts)
  vim.api.nvim_create_user_command("Zw", function(opts_)
    M.cd(opts_, "window")
  end, copts)
  vim.api.nvim_create_user_command("Zt", function(opts_)
    M.cd(opts_, "tabs")
  end, copts)
end

-- Provide completions for the cmdline. Only return completions if number of
-- arguments is 1
-- We can't complete multiple arguments as generally all the arguments are
-- parts of strings of entries in zoxide's database
function M.complete(arglead, cmdline, _)
  local current_path = vim.fn.getcwd()
  local cmd =
    { M.opts.zoxide_cmd, "query", "-l", "--exclude=" .. current_path, "--" }
  local args = vim.api.nvim_parse_cmd(cmdline, {}).args
  local home = os.getenv("HOME") .. "/"

  -- If number of arguments passed to ':Z' is greater than 1, we cannot provide
  -- completions as you can pass almost anything to 'z', and anyways z doesn't
  -- even provide completions so we are doing more than what's needed :)
  if #args > 1 or (#args == 1 and #arglead == 0) then
    return {}
  end

  local dir_completes = {}

  if #args == 0 then
    local dir = vim.loop.fs_opendir(current_path, nil, 1)
    while true do
      local entry = vim.loop.fs_readdir(dir)
      -- We've read everything
      if entry == nil then
        vim.loop.fs_closedir(dir)
        break
      end

      -- Only add to completions if is a directory, also if it is a symlink, try to resolve it and add it too if it is a directory
      local name
      if entry[1].type == "directory" then
        name = entry[1].name
      elseif entry[1].type == "link" then
        local link_dir =
          vim.loop.fs_opendir(current_path .. "/" .. entry[1].name)
        if link_dir ~= nil then
          name = entry[1].name
          vim.loop.fs_closedir(link_dir)
        else
          goto continue
        end
      else
        goto continue
      end
      dir_completes[#dir_completes + 1] = name
      ::continue::
    end
  end

  -- If exactly one argument is passed, we can do our best to complete its
  -- Completion item can be a relative directory, absolute directory or any of
  -- the entries in zoxide's database
  if #args == 1 then
    -- Get the last directory we can make out of from the string
    local dir_string = args[1]:match(".*/") or "./"
    -- Expand the tilde expression to home
    if home ~= nil and vim.startswith(dir_string, "~/") then
      dir_string = home .. string.sub(dir_string, 3)
    end
    local dir = vim.loop.fs_opendir(dir_string, nil, 1)
    -- If this is a directory, read it and provide the completions for directories in the directory which the user has typed out
    if dir ~= nil then
      while true do
        local entry = vim.loop.fs_readdir(dir)
        -- We've read everything
        if entry == nil then
          vim.loop.fs_closedir(dir)
          break
        end
        -- Only add to completions if is a directory, also if it is a symlink, try to resolve it and add it too if it is a directory
        local name
        if entry[1].type == "directory" then
          name = entry[1].name
        elseif entry[1].type == "link" then
          local link_dir = vim.loop.fs_opendir(dir_string .. entry[1].name)
          if link_dir ~= nil then
            name = entry[1].name
            vim.loop.fs_closedir(link_dir)
          else
            goto continue
          end
        else
          goto continue
        end
        -- fuzzy search on steroids
        local x = ".*" .. table.concat(vim.split(args[1], ""), ".*") .. ".*"
        -- Filter completion results to options that match the user string
        if string.match(dir_string .. name, x) then
          dir_completes[#dir_completes + 1] = dir_string .. name
        end
        ::continue::
      end
    end
  end
  -- Do not pass any arguments to zoxide since we are using a hacky fuzzy search whereas zoxide doesn't do fuzzy search
  local zoxide_output = vim.fn.system(cmd)
  -- Although this should not happen, but let's just handle it just in case
  if vim.v.shell_error ~= 0 then
    error(zoxide_output)
  end
  -- Read the directories in zoxide database and separate each entry
  local zoxide_entries =
    vim.split(zoxide_output, "\n", { plain = true, trimempty = false })
  local completions = {}
  -- we just converted the tilde earlier to HOME, as vim.loop doesn't understand it. So let's convert back
  for _, entry in pairs(dir_completes) do
    if home ~= nil and vim.startswith(entry, home) then
      entry = "~/" .. string.sub(entry, #home + 1)
    end
    completions[#completions + 1] = entry
  end
  -- zoxide will return full path, so let's just replace the user directory with shorthand tilde notation to make the suggestions size smaller on screen.
  for _, entry in pairs(zoxide_entries) do
    if home ~= nil and vim.startswith(entry, home) then
      entry = "~/" .. string.sub(entry, #home + 1)
    end
    -- Fuzzy search on steroids part2
    if
      #args == 1
      and string.match(
        entry,
        ".*" .. table.concat(vim.split(args[1], ""), ".*") .. ".*"
      )
    then
      completions[#completions + 1] = entry
    end
  end
  -- Finally return the completions back
  return completions
end

-- Resolve the argument(s) provided to paths which can be cded into
function M.resolve(args)
  local home = os.getenv("HOME")

  -- If no argument is supplied, just send the user to home.
  -- Same for tilde, expand ourselves instead of relying on NeoVim to do that for us
  if #args == 0 or (#args == 1 and args[1] == "~") then
    return home
  end

  if #args == 1 then
    -- Return as is if it is relative path, do not try to verify if it exists or not
    if vim.startswith(args[1], "./") then
      return args[1]
    end

    -- Most shells expand the tilde expression themselves, so the behaviour which we get is the same as the below case, but zoxide doesn't understand the '~' character as "$HOME" as '~' is a valid character that can be used to name files and directories on a lot of filesystems, so have to expand it ourselves
    if home ~= nil and vim.startswith(args[1], "~/") then
      args[1] = home .. "/" .. string.sub(args[1], 3)
    end

    -- If an absolute path, first check if destination is a directory, if directory then return it
    -- If not a directory, then ask zoxide to resolve it
    -- If the path exists relative to the current directory, simply cd there instead of looking up in the database.
    local dir = vim.loop.fs_opendir(args[1])
    if dir ~= nil then
      vim.loop.fs_closedir(dir)
      -- This is needed as relative directories need to be resolved for
      -- `zoxide add` to work properly, or else the matching one will not be the
      -- relative directory where we just cd into
      return vim.loop.fs_realpath(args[1])
    end
  end

  -- Explicitly ask zoxide not to return the current directory itself
  -- Although this should not be needed
  local current_path = vim.fn.getcwd()
  local cmd = { M.opts.zoxide_cmd, "query", "--exclude=" .. current_path }
  cmd[#cmd + 1] = "--"

  -- Append the arguments provided to ':Z' to zoxide commannd
  for _, part in pairs(args) do
    cmd[#cmd + 1] = part
  end

  -- zoxide by default should only return one path on success. So just take the program output
  local path = vim.fn.system(cmd)

  -- If something went wrong, return a table with the path returned by the zoxide command and the exit code
  if vim.v.shell_error ~= 0 then
    return { path, vim.v.shell_error }
  end

  -- If last character is a newline character, just strip it off
  if string.sub(path, -1, -1) == "\n" then
    path = string.sub(path, 0, -2)
  end

  -- Return the resolved path
  return path
end

-- The actual function that is executed when ':Z' is called
function M.cd(opts, behaviour)
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
  if behaviour == "tabs" then
    vim.cmd("tcd " .. target)
  elseif behaviour == "window" then
    vim.cmd("lcd " .. target)
  elseif behaviour == "global" then
    vim.cmd("cd " .. target)
  end
end

return M
