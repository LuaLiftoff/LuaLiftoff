
local function id(x) return x end

local function addRule(match, replacer)
   assert(type(match) == 'table')
   assert(replacer == nil or type(replacer) == "function")
   if not replacer then replacer = id end
   if match.type then
      match = {match}
   end
   local leaves = {}
   local inner = {}

end

addRule{type = "ADD", {type = "CONST", value = 0}, {arg = 1}}
addRule({type = "MUL", {type = "CONST", value = 2}, {arg = 1}}, {type = "ADD", 1, 1})
