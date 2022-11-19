-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local string = require "string"
local global = require "_G"

return {
   byte = string.byte,
   char = string.char,
   dump = string.dump,
   find = string.find,
   format = string.format,
   gmatch = string.gmatch,
   gsub = string.gsub,
   len = string.len,
   lower = string.lower,
   match = string.match,
   rep = string.rep,
   reverse = string.reverse,
   sub = string.sub,
   upper = string.upper,
   to_string = global.tostring,
}
