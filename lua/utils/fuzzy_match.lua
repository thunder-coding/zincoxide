-- Fuzzy search against a pattern.
-- @param str The string to search within.
-- @param pattern The pattern to match against.
--                The pattern is just a string without any special regex
--                characters.
local function fuzzy_match(str, pattern)
  local pattern_index = 1
  for i = 1, #str do
    if str:sub(i, i) == pattern:sub(pattern_index, pattern_index) then
      pattern_index = pattern_index + 1
    end
    if pattern_index > #pattern then
      return true
    end
  end
  return false
end

return fuzzy_match
