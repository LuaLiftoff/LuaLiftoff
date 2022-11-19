-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require "lualiftoff.util.class"
local table = require "lualiftoff.lua.table"
local assert = require "lualiftoff.lua.assert"
local vararg = require "lualiftoff.lua.vararg"
local string = require "lualiftoff.lua.string"

local Graph = Class "Graph"
local Node = Class "Node"

local INPUT_OFFSET = 3

local function accumulate_hash(hash, value)
   return (hash + value) % 0x80000000
end

local function end_hash(hash)
   if hash == 0 then hash = 1 end
   return hash
end

function Graph.__index:init(reducer)
   self.lookup_table = {}
   self.next_id = 1
   self.removed = {}
   self.dirty_queue = {}
   self.reducer = reducer
   return self
end

local function base_hash(type)
   assert(type ~= Node)
   local hash = type.base_hash_cache
   if hash then return hash end
   hash = 0
   local name = type.name
   for i = 1, #name do
      hash = accumulate_hash(hash, string.byte(name, i))
   end
   type.base_hash_cache = hash
   return hash
end

function Graph.__index:lookup(type, ...)
   assert(Node:is_assignable_from(type) and Node ~= type)
   local hash = base_hash(type)
   local num_args = vararg.select("#", ...)
   for i = 1, num_args do
      local arg = vararg.select(i, ...)
      hash = accumulate_hash(hash, arg:id())
   end
   hash = end_hash(hash)
   assert(hash ~= 0)
   local lookup_hash = hash
   local free_hash
   while true do
      local n = self.lookup_table[lookup_hash]
      if n == nil then break end
      if n == false then
         free_hash = lookup_hash
      elseif Class:get_class(n) == type and n:input_count() == num_args then
         local eq = true
         for i = 1, num_args do
            if n:get_input(i) ~= vararg.select(i, ...) then
               eq = false
               break
            end
         end
         if eq then
            assert(n[3] == hash or n[3] == -hash)
            return n, hash, lookup_hash
         end
      end
      lookup_hash = (lookup_hash + 1) % 0x80000000
   end
   return nil, hash, free_hash or lookup_hash
end

function Graph.__index:create(type, ...)
   local node, hash, free_slot = self:lookup(type, ...)
   if node then return node end
   local list = self.removed
   local idx = #list
   local id = self.next_id
   self.next_id = id + 1
   if idx == 0 then
      node = type(id, ...)
   else
      node = list[idx]
      list[idx] = nil
      assert(node[1] == 0)
      assert(node[2] == -1)
      assert(node[3] == 0)
      table.setmetatable(node, type)
      node = node:init(id, ...)
   end
   node[3] = -hash
   self.lookup_table[free_slot] = node
   self.dirty_queue[#self.dirty_queue + 1] = node
   return node
end

function Graph.__index:remove_node_from_lookup_table(node)
   local lookup_hash = node[3]
   if lookup_hash == 0 then return end -- Already removed
   if lookup_hash < 0 then
      lookup_hash = -lookup_hash
   end

   node[3] = 0
   while true do
      local n = self.lookup_table[lookup_hash]
      assert(n ~= nil)
      local next_hash = (lookup_hash + 1) % 0x80000000
      if n == node then
         if self.lookup_table[next_hash] == nil then
            self.lookup_table[lookup_hash] = nil
         else
            self.lookup_table[lookup_hash] = false
         end
         break
      end
      lookup_hash = next_hash
   end
end

function Graph.__index:invalidate(node)
   if node[3] > 0 then
      self.dirty_queue[#self.dirty_queue + 1] = node
   end
   self:remove_node_from_lookup_table(node)
end

function Graph.__index:mark_dirty(node)
   local lookup_hash = node[3]
   if lookup_hash <= 0 then return end -- Already dirty
   node[3] = -lookup_hash
   self.dirty_queue[#self.dirty_queue + 1] = node
end

function Graph.__index:reduce_node(node)
   return self.reducer:reduce(self, node)
end

function Graph.__index:push_all_uses_group(node)
   return self.reducer:revalidate_node(self, node)
end

function Graph.__index:handle_dirty()
   while true do
      local idx = #self.dirty_queue
      if idx == 0 then return end
      local node = self.dirty_queue[idx]
      self.dirty_queue[idx] = nil

      assert(node[3] <= 0)

      local dead = node:use_count() == 0

      if not dead then
         if node[3] == 0 then
            local other_node, hash, free_slot = self:lookup(node:type(), node:all_inputs())
            if other_node then
               node:replace_with(other_node)
               dead = true
            else
               node[3] = hash
               self.lookup_table[free_slot] = node
               self:reduce_node(node)
               self:push_all_uses_group(node)
            end
         else
            node[3] = -node[3]
            self:reduce_node(node)
         end
      end

      if dead then
         -- No uses, delete node
         self:remove_node_from_lookup_table(node)
         node[2] = -1
         local inputs = node[1]
         node[1] = 0
         for i = inputs + INPUT_OFFSET, INPUT_OFFSET + 1, -1 do
            local n = node[i]
            node[i] = nil
            n:remove_use(self, node)
         end
         assert(#node == 3)
         self.removed[#self.removed + 1] = node
      end
   end
end

function Node.__index:init(id, ...)
   local num_args = vararg.select("#", ...)
   self[1] = num_args
   self[2] = id
   self[3] = 0
   for i = 1, num_args do
      local arg = vararg.select(i, ...)
      assert(Node:is_instance(arg))
      self[i + INPUT_OFFSET] = arg
      arg:add_use(self)
   end
   return self
end

function Node.__index:type()
   return table.getmetatable(self)
end

function Node.__index:set_type(type)
   return table.setmetatable(self, type)
end

function Node.__index:id()
   return self[2]
end

function Node.__index:is_dead()
   return self[2] == -1
end

function Node.__index:set_inputs(graph, ...)
   assert(Graph:is_instance(graph))
   local num_args = vararg.select("#", ...)
   local curr_args = self:input_count()
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
      local arg = vararg.select(i, ...)
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
   assert(Graph:is_instance(graph))
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
   assert(Graph:is_instance(graph))
   local inputs = self:input_count()
   if idx == nil then idx = inputs + 1 end
   assert(idx >= 1 and idx <= inputs + 1)
   assert(Node:is_instance(node))
   idx = idx + INPUT_OFFSET
   self[#self + 1] = self[inputs + 1 + INPUT_OFFSET]
   self[1] = inputs + 1
   table.move(self, idx, inputs + INPUT_OFFSET, idx + 1)
   self[idx] = node
   node:add_use(self)
   graph:invalidate(self)
end

function Node.__index:remove_input(graph, idx)
   assert(Graph:is_instance(graph))
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
   assert(Graph:is_instance(graph))
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

function Node.__index:remove_input_fast_shuffle(graph, idx)
   assert(Graph:is_instance(graph))
   local inputs = self:input_count()
   assert(idx >= 1 and idx <= inputs)
   idx = idx + INPUT_OFFSET
   local old = self[idx]
   self[1] = inputs - 1
   self[idx] = self[inputs + INPUT_OFFSET]
   self[inputs + INPUT_OFFSET] = self[#self]
   self[#self] = nil
   old:remove_use(graph, self)
   graph:invalidate(self)
   return old
end

local function input_iterator(node, idx)
   idx = idx + 1
   if idx > node:input_count() then return nil end
   return idx, node:get_input(idx)
end

function Node.__index:inputs()
   return input_iterator, self, 0
end

function Node.__index:all_inputs()
   return table.unpack(self, INPUT_OFFSET + 1, INPUT_OFFSET + 1 + self:input_count())
end

function Node.__index:use_count()
   return #self - self:input_count() - INPUT_OFFSET
end

function Node.__index:add_use(node)
   assert(Node:is_instance(node))
   self[#self + 1] = node
end

function Node.__index:remove_use(graph, node)
   assert(Graph:is_instance(graph))
   assert(Node:is_instance(node))
   local last = #self
   for i = self:input_count() + INPUT_OFFSET + 1, last do
      if self[i] == node then
         self[i] = self[last]
         self[last] = nil
         if i == last and last == self:input_count() + INPUT_OFFSET + 1 then
            -- Last use is removed, mark dirty and remove later
            graph:mark_dirty(self)
         end
         return
      end
   end
   assert(false)
end

function Node.__index:replace_with(graph, node)
   assert(Graph:is_instance(graph))
   assert(Node:is_instance(node))
   if self == node then return end
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

Graph.Node = Node

return Graph
