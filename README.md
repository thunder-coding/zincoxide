# ZincOxide (ZnO)

Supercharge your neovim cd command with new your existing shell's `zoxide`.

# Installation (lazy.nvim)

```lua
{
  -- You can also use the codeberg mirror if you want to use the plugin without relying on GitHub
  -- "https://codeberg.org/CodingThunder/zincoxide.git" -- for HTTPS
  -- "git@codeberg.org:CodingThunder/zincoxide.git"     -- for SSH
  "thunder-coding/zincoxide",
  opts = {
    -- Path to zoxide binary on your system
    zincoxide_cmd = "/usr/bin/zoxide",
    -- Kinda experimental as of now
    complete = true,
    -- Available options { "tabs", "window", "global" }
    behaviour = "tabs",
  },
  cmd = { "Z" },
}
```
