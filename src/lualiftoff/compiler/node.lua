-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require"lualiftoff.util.class"

local Graph = Class"Graph"
local Node = Class"Node"

local INPUT_OFFSET = 3

function Graph.__index:init()
   self.lookup = {}
   self.next_id = 1
   self.remove_queue = {}
   self.removed = {}
   self.invalidated = {}
   return self
end

function Graph.__index:get_id(node)
   assert(Node:is_instance(node))
   local id = node[2]
   if id == 0 then
      id = self.next_id
      self.next_id = id + 1
      node[2] = id
   end
   return id
end

function Graph.__index:create(type, ...)
   local hash = type.base_hash
   local num_args = select('#', ...)
   for i = 1, num_args do
      local arg = select(i, ...)
      hash = (hash + self:get_id(arg)) % 0x80000000
   end
   if hash == 0 then hash = 1 end
   local lookup_hash = hash
   local free_hash
   while true do
      local node = self.lookup[lookup_hash]
      if node == nil then break end
      if node == false then
         free_hash = lookup_hash
      elseif Class:get_class(node) == type and node:input_count() == num_args then
         local eq = true
         for i = 1, num_args do
            if node:get_input(i) ~= select(i, ...) then
               eq = false
               break
            end
         end
         if eq then
            return node
         end
      end
      lookup_hash = (lookup_hash + 1) % 0x80000000
   end
   local node
   local list = self.removed
   local idx = #list
   if idx == 0 then
      node = type(...)
   else
      node = list[idx]
      list[idx] = nil
      node[2] = 0
      node:change_node(self, type, ...)
   end
   node[3] = hash
   self.lookup[free_hash or lookup_hash] = node
   return node
end

function Graph.__index:remove_node_from_table(node)
   assert(Node:is_instance(node))
   local lookup_hash = node[3]
   if lookup_hash == 0 then return end
   node[3] = 0
   while true do
      local n = self.lookup[lookup_hash]
      assert(n ~= nil)
      local next_hash = (lookup_hash + 1) % 0x80000000
      if n == node then
         if self.lookup[next_hash] == nil then
            self.lookup[lookup_hash] = nil
         else
            self.lookup[lookup_hash] = false
         end
         return
      end
      lookup_hash = next_hash
   end
end

function Graph.__index:invalidate(node)
   local lookup_hash = node[3]
   if lookup_hash == 0 then return end
   self:remove_node_from_table(node)
   self.invalidated[#self.invalidated+1] = node
end

function Graph.__index:deduplicate(node)
   assert(Node:is_instance(node))
   local type = Class:get_class(node)
   assert(type)
   if node[3] ~= 0 then return node end
   local hash = type.base_hash
   local num_args = node:input_count()
   for i = 1, num_args do
      local arg = node:get_input(i)
      hash = (hash + self:get_id(arg)) % 0x80000000
   end
   if hash == 0 then hash = 1 end
   local lookup_hash = hash
   local free_hash
   while true do
      local n = self.lookup[lookup_hash]
      if n == nil then break end
      if n == false then
         free_hash = lookup_hash
      elseif Class:get_class(n) == type and n:input_count() == num_args then
         local eq = true
         for i = 1, num_args do
            if n:get_input(i) ~= node:get_input(i) then
               eq = false
               break
            end
         end
         if eq then
            node:replace_with(self, n)
            return n
         end
      end
      lookup_hash = (lookup_hash + 1) % 0x80000000
   end
   node[3] = hash
   self.lookup[free_hash or lookup_hash] = node
   return node
end

function Graph.__index:deduplicate_invalidated()
   while true do
      local idx = #self.invalidated
      if idx == 0 then return end
      local node = self.invalidated[idx]
      self.invalidated[idx] = nil
      self:deduplicate(node)
   end
end

function Graph.__index:mark_for_removal(node)
   assert(Node:is_instance(node))
   assert(node:use_count() == 0)
   self.remove_queue[#self.remove_queue+1] = node
end

function Graph.__index:do_remove()
   while true do
      local idx = #self.remove_queue
      if idx == 0 then return end
      local node = self.remove_queue[idx]
      self.remove_queue[idx] = nil
      if node:use_count() == 0 then
         self:remove_node_from_table(node)
         local inputs = node[1]
         node[1] = 0
         for i = inputs + INPUT_OFFSET, INPUT_OFFSET + 1, -1 do
            local n = node[i]
            node[i] = nil
            n:remove_use(node)
         end
         self.removed[#self.removed+1] = node
      end
   end
end

function Node.__index:init(...)
   local num_args = select('#', ...)
   self[1] = num_args
   self[2] = 0
   self[3] = 0
   for i = 1, num_args do
      local arg = select(i, ...)
      assert(Node:is_instance(arg))
      self[i + INPUT_OFFSET] = arg
      arg:add_use(self)
   end
   return self
end

function Node.__index:change_node(graph, new_type, ...)
   local num_args = select('#', ...)
   local curr_args = self:input_count()
   setmetatable(self, new_type)
   for i = 1, curr_args do
      self[i + INPUT_OFFSET]:remove_use(graph, self)
   end
   if num_args > curr_args then
      table.move(self, curr_args + INPUT_OFFSET + 1, num_args + INPUT_OFFSET + 1, #self + 1)
   else
      local l = #self
      for i = curr_args, num_args, -1 do
         self[i + INPUT_OFFSET + 1] = self[l]
         self[l] = nil
         l = l - 1
      end
   end
   self[1] = num_args
   for i = 1, num_args do
      local arg = select(i, ...)
      assert(Node:is_instance(arg))
      self[i + INPUT_OFFSET] = arg
      arg:add_use(self)
   end
   graph:invalidate(self)
end

function Node.__index:input_count()
   return self[1]
end

function Node.__index:get_input(idx)
   assert(idx >= 1 and idx <= self:input_count())
   return self[idx + INPUT_OFFSET]
end

function Node.__index:set_input(graph, idx, node)
   assert(idx >= 1 and idx <= self:input_count())
   assert(Node:is_instance(node))
   idx = idx + INPUT_OFFSET
   local old = self[idx]
   self[idx] = node
   node:add_use(self)
   old:remove_use(graph, self)
   graph:invalidate(self)
   return old
end

function Node.__index:add_input(graph, node, idx)
   local inputs = self:input_count()
   if idx == nil then idx = inputs + 1 end
   assert(idx >= 1 and idx <= inputs + 1)
   assert(Node:is_instance(node))
   idx = idx + INPUT_OFFSET
   self[#self+1] = self[inputs + 1 + INPUT_OFFSET]
   self[1] = inputs + 1
   table.move(self, idx, inputs + INPUT_OFFSET, idx + 1)
   self[idx] = node
   node:add_use(self)
   graph:invalidate(self)
end

function Node.__index:remove_input(graph, idx)
   local inputs = self:input_count()
   assert(idx >= 1 and idx <= inputs)
   idx = idx + INPUT_OFFSET
   local old = self[idx]
   self[1] = inputs - 1
   table.move(self, idx + 1, inputs + INPUT_OFFSET, idx)
   self[inputs + INPUT_OFFSET] = self[#self]
   self[#self] = nil
   old:remove_use(graph, self)
   graph:invalidate(self)
   return old
end

function Node.__index:replace_input(graph, old, new)
   for i = 1, self:input_count() do
      local idx = i + INPUT_OFFSET
      if self[idx] == old then
         self[idx] = new
         new:add_use(self)
         old:remove_use(graph, self)
      end
   end
   graph:invalidate(self)
end

local function input_iterator(node, idx)
   idx = idx + 1
   if idx > node:input_count() then return nil end
   return idx, node:get_input(idx)
end

function Node.__index:inputs()
   return input_iterator, self, 0
end

function Node.__index:use_count()
   return #self - self:input_count() - INPUT_OFFSET - 1
end

function Node.__index:add_use(node)
   assert(Node:is_instance(node))
   self[#self+1] = node
end

function Node.__index:remove_use(graph, node)
   assert(Node:is_instance(node))
   local last = #self
   for i = self:input_count() + INPUT_OFFSET + 1, last do
      if self[i] == node then
         self[i] = self[last]
         self[last] = nil
         if i == last and last == self:input_count() + INPUT_OFFSET + 1 then
            -- Last use is removed
            graph:mark_for_removal(self)
         end
         return
      end
   end
   assert(false)
end

function Node.__index:replace_with(graph, node)
   while true do
      local idx = self:input_count() + INPUT_OFFSET + 1
      local use = self[idx]
      if use == nil then return end
      use:replace_input(graph, self, node)
      assert(self[idx] ~= use)
   end
end

local function ipair_iterator(tab, idx)
   idx = idx + 1
   local val = tab[idx]
   if val == nil then return nil end
   return idx, val
end

function Node.__index:uses()
   return ipair_iterator, self, self:input_count() + INPUT_OFFSET
end

return Node
