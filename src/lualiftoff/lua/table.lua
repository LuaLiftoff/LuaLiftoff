-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local table = require "table"
local global = require "_G"
local select = global.select

local function move(a1, f, e, t, a2)
   if a2 == nil then a2 = a1 end
   if t < f or t > e then
      for i = f, e do
         a2[t] = a1[i]
         t = t + 1
      end
   else
      t = t + (e - f)
      for i = e, f, -1 do
         a2[t] = a1[i]
         t = t - 1
      end
   end
   return a2
end

local function pack(...)
   local n = select("#", ...)
   local t = {n = n}
   for i = 1, n do
      t[i] = select(i, ...)
   end
   return t
end

return {
   concat = table.concat,
   insert = table.insert,
   remove = table.remove,
   sort = table.sort,
   move = table.move or move,
   unpack = table.unpack or global.unpack,
   pack = table.pack or pack,
   pairs = global.pairs,
   ipairs = global.ipairs,
   next = global.next,
   setmetatable = global.setmetatable,
   getmetatable = global.getmetatable,
}
