-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local table = require "lualiftoff.lua.table"
local assert = require "lualiftoff.lua.assert"
local global = require "_G"

local Object = {
   name = "Object",
   __index = {}
}

function Object.__index.__new(class, ...)
   local obj = table.setmetatable({}, class)
   return obj:init(...)
end

function Object.__index:init()
   return self
end

local Class = {
   name = "Class",
   __index = {},
   __call = function(self, ...)
      return self.__index.__new(self, ...)
   end
}

Class.type = global.type

function Class.__index:init(name, super)
   assert(Class.type(name) == "string")
   assert(not super or Class:is_instance(super))
   self.name = name
   self.__index = table.setmetatable({}, super or Object)
   return self
end

function Class.__index:extend(name)
   return Class(name, self)
end

function Class.__index:get_super()
   return table.getmetatable(self.__index)
end

function Class.__index:super()
   return self:get_super().__index
end

function Class:get_class(obj)
   if Class.type(obj) ~= "table" then return nil end
   local class = table.getmetatable(obj)
   if table.getmetatable(class) ~= Class then return nil end
   return class
end

function Class.__index:is_instance(obj)
   local class = Class:get_class(obj)
   return class and self:is_assignable_from(class)
end

function Class.__index:is_assignable_from(other)
   assert(table.getmetatable(other) == Class)
   while other do
      if other == self then
         return true
      end
      other = other:get_super()
   end
   return false
end

table.setmetatable(Class, Class)
table.setmetatable(Class.__index, Object)
table.setmetatable(Object, Class)

return Class
