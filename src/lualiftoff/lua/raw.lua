-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local global = require "_G"

local function rawlen(x)
   return #x
end

return {
   rawequal = global.rawequal,
   rawget = global.rawget,
   rawset = global.rawset,
   rawlen = global.rawlen or rawlen,
}
