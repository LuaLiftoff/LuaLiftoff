-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require "lualiftoff.util.class"
local assert = require "lualiftoff.lua.assert"
local table = require "lualiftoff.lua.table"

local Reducer = Class "Reducer"


function Reducer.__index:init()
   self.rules = {}
   self.reverse_groups = {match = false, children = false, generic = false}
   return self
end

local function id(_graph, x) return x end

local function match(node, pattern, args)
   local max_arg = 0
   if pattern.type and node:type() ~= pattern.type then return -1 end
   if pattern.arg then
      max_arg = pattern.arg
      args[max_arg] = node
   end
   if #pattern == 0 then return max_arg end
   if #pattern ~= node:input_count() then return -1 end
   for i, input in node:inputs() do
      local n = match(input, pattern[i], args)
      if n == -1 then return -1 end
      if n > max_arg then max_arg = n end
   end
   return max_arg
end

local function table_get_table(tab, key)
   local l = tab[key]
   if not l then
      l = {}
      tab[key] = l
   end
   return l
end

local function table_add_to_list(tab, key, value)
   local list = table_get_table(tab, key)
   list[#list + 1] = value
end

local function clone_reverse_mapping(c)
   if not c then return {match = false, children = false, generic = false} end
   local copy = {match = c.match, children = c.children, generic = false}
   for k, v in table.ipairs(c) do
      if Class.type(k) == "table" then
         copy[k] = clone_reverse_mapping(v)
      end
   end
   return copy
end

local function merge_reverse_list(c, reverse_list, idx)
   for i = idx, 1, -1 do
      local t = reverse_list[i]
      if t == nil then
         for k, v in table.ipairs(c) do
            if Class.type(k) == "table" then
               merge_reverse_list(v, reverse_list, i - 1)
            end
         end
         t = "generic"
      end
      local l = c[t]
      if not l then
         c.children = true
         l = clone_reverse_mapping(c.generic)
         c[t] = l
      end
      c = l
   end
   c.match = true
end

function Reducer.__index:merge_reverse_list(reverse_list, idx)
   merge_reverse_list(self.reverse_groups, reverse_list, idx)
end

function Reducer.__index:create_pattern(pattern, reverse_list, idx)
   local copy = {
      type = pattern.type,
      arg = pattern.arg,
      value = pattern.value,
      parent = pattern.parent
   }
   reverse_list[idx] = pattern.type
   if #pattern == 0 then return copy end
   for i, v in table.ipairs(pattern) do
      copy[i] = self:create_pattern(v, reverse_list, idx + 1)
   end
   if idx > 1 then
      self:merge_reverse_list(reverse_list, idx)
   end
   return copy
end

function Reducer.__index:add_rule(pattern, replacer)
   assert(Class.type(pattern) == "table")
   assert(replacer == nil or Class.type(replacer) == "function")
   if not replacer then replacer = id end
   local p = self:create_pattern(pattern, {}, 1)
   table_add_to_list(self.rules, p.type, {pattern = p, replacer = replacer})
end

function Reducer.__index:reduce(graph, node)
   local rules = self.rules[node:type()]
   if not rules then return false end
   local args = {}
   for i = 1, #rules do
      local rule = rules[i]
      local num = match(node, rule.pattern, args)
      if num >= 0 then
         local new_node = rule.replacer(graph, table.unpack(args, 1, num))
         if new_node then
            node:replace_with(graph, new_node)
            return true
         elseif node:use_count() == 0 then
            return true
         end
      end
   end
   return false
end

local function reverse_match(graph, node, rule)
   if rule.match then
      graph:mark_dirty(node)
   end
   if rule.children then
      for _, use in node:uses() do
         local r = rule[use:type()] or rule.generic
         if r then
            reverse_match(graph, use, r)
         end
      end
   end
end

function Reducer.__index:revalidate_node(graph, node)
   local rule = self.reverse_groups[node:type()] or self.reverse_groups.generic
   if rule then
      reverse_match(graph, node, rule)
   end
end

return Reducer
