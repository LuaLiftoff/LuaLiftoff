
-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require"lualiftoff.util.class"

local Visitor = Class"Visitor"

function Visitor.__index:visit(node)
   return node:visit(self)
end

return Visitor
