-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require "lualiftoff.util.class"
local Graph = require "lualiftoff.compiler.graph"
local Reducer = require "lualiftoff.compiler.reducer"
local Node = require "lualiftoff.compiler.node"

describe("Graph", function()
   it("ordered-ids", function()
      local graph = Graph(Reducer())
      local t1 = Class("DUMMY", Node)
      local t2 = Class("DUMMY2", Node)
      local t3 = Class("DUMMY3", Node)
      local n1 = graph:create(t1)
      assert.same(1, n1:id())
      local n2 = graph:create(t2)
      assert.same(2, n2:id())
      local n3 = graph:create(t3, n1, n2)
      assert.same(3, n3:id())
      local n4 = graph:create(t3, n2, n2)
      assert.same(4, n4:id())
   end)
   it("deduplicate", function()
      local graph = Graph(Reducer())
      local t1 = Class("DUMMY", Node)
      local t2 = Class("DUMMY2", Node)
      local n1 = graph:create(t1)
      local n2 = graph:create(t1)
      assert.same(n1, n2)
      local n3 = graph:create(t2, n1, n2)
      assert.not_same(n1, n3)
      local n4 = graph:create(t2, n2, n2)
      assert.same(n3, n4)
   end)
   it("remove", function()
      local graph = Graph(Reducer())
      local t1 = Class("DUMMY", Node)
      local t2 = Class("DUMMY2", Node)
      local n1 = graph:create(t1)
      graph:handle_dirty()
      assert(n1:is_dead())
      local n2 = graph:create(t1)
      assert.same(n1, n2) -- Reuse dead nodes
      local n3 = graph:create(t2)
      n3:add_input(graph, n3)
      n3:add_input(graph, n2)
      graph:handle_dirty()
      assert(not n2:is_dead())
      assert(not n3:is_dead())
      n3:remove_input(graph, 1)
      graph:handle_dirty()
      assert(n2:is_dead())
      assert(n3:is_dead())
   end)
end)
