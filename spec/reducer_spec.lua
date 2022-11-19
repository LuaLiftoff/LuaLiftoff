-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require "lualiftoff.util.class"
local Graph = require "lualiftoff.compiler.graph"
local Reducer = require "lualiftoff.compiler.reducer"
local Node = require "lualiftoff.compiler.node"

describe("Reducer", function()
   it("reduce", function()
      local h = Class("HOLDER", Node)
      local t1 = Class("DUMMY", Node)
      local t2 = Class("DUMMY2", Node)
      local reducer = Reducer()
      reducer:add_rule({type = t2, {type = t1, arg = 1}})
      local graph = Graph(reducer)
      local holder = graph:create(h)
      holder:add_input(graph, holder) -- Stop it from being removed
      local n1 = graph:create(t1)
      local n2 = graph:create(t2, n1)
      holder:add_input(graph, n2)
      graph:handle_dirty()
      assert.same(n1, holder:get_input(2))
   end)
   it("reduce-eq-chain", function()
      local h = Class("HOLDER", Node)
      local t1 = Class("DUMMY", Node)
      local t2 = Class("DUMMY2", Node)
      local t3 = Class("DUMMY3", Node)
      local t4 = Class("DUMMY4", Node)
      local reducer = Reducer()
      reducer:add_rule({type = t4, {type = t3, {type = t2, {type = t1, arg = 1}}}})
      local graph = Graph(reducer)
      local holder = graph:create(h)
      holder:add_input(graph, holder) -- Stop it from being removed
      local n1 = graph:create(t1)
      local n2 = graph:create(t2, n1)
      local n3 = graph:create(t2, n2)
      local n4 = graph:create(t3, n3)
      local n5 = graph:create(t4, n4)
      holder:add_input(graph, n5)
      graph:handle_dirty()
      assert.same(n5, holder:get_input(2))
      n3:set_input(graph, 1, n1)
      graph:handle_dirty()
      assert.same(n1, holder:get_input(2))
   end)
end)
