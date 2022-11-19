-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require "lualiftoff.util.class"
local assert = require "lualiftoff.lua.assert"
local error = require "lualiftoff.lua.error"

local Ast = Class "Ast"

local function AstNode(name, super)
   local class = Class(name, super)
   super[name] = class
   return class
end

local Statements = AstNode("Statements", Ast)
local Identifier = AstNode("Identifier", Ast)
local ExpressionList = AstNode("ExpressionList", Ast)
local Declaration = AstNode("Declaration", Ast)
local Record = AstNode("Record", Ast)

local Statement = AstNode("Statement", Ast)
local Empty = AstNode("Empty", Statement)
local Assignment = AstNode("Assignment", Statement)
local Local = AstNode("Local", Statement)
local Return = AstNode("Return", Statement)
local ExpressionStatement = AstNode("ExpressionStatement", Statement)
local Break = AstNode("Break", Statement)
local If = AstNode("If", Statement)
local ForNum = AstNode("ForNum", Statement)
local ForIn = AstNode("ForIn", Statement)
local While = AstNode("While", Statement)
local Repeat = AstNode("Repeat", Statement)
local Block = AstNode("Block", Statement)
local LocalFunction = AstNode("LocalFunction", Statement)
local Label = AstNode("Label", Statement)
local Goto = AstNode("Goto", Statement)

local Expression = AstNode("Expression", Ast)
local Variable = AstNode("Variable", Expression)
local Number = AstNode("Number", Expression)
local String = AstNode("String", Expression)
local Table = AstNode("Table", Expression)
local Function = AstNode("Function", Expression)
local BinaryOp = AstNode("BinaryOp", Expression)
local UnaryOp = AstNode("UnaryOp", Expression)
local Call = AstNode("Call", Expression)
local MethodCall = AstNode("MethodCall", Expression)
local True = AstNode("True", Expression)
local False = AstNode("False", Expression)
local Nil = AstNode("Nil", Expression)
local Varargs = AstNode("Varargs", Expression)

function Ast.__index:init(start_position, end_position)
   assert(Class.type(start_position) == "number")
   assert(Class.type(end_position) == "nil" or Class.type(end_position) == "number")
   self.start_position = start_position
   self.end_position = end_position or start_position
   return self
end

function Ast.__index:set_end(position)
   assert(Class.type(position) == "number")
   self.end_position = position
   return self
end

function Ast.__index:visit(_visitor)
   error.error("NYI")
end

function Ast.__index:visit_codegen(_visitor)
   error.error("NYI")
end

function Statements.__index:init(start_position, end_position, statements)
   self = Statements:super().init(self, start_position, end_position)
   assert(statements == nil or Class.type(statements) == "table")
   self.statements = statements or {}
   return self
end

function Statements.__index:add_statement(statement)
   assert(Statement:is_instance(statement))
   self.statements[#self.statements + 1] = statement
   return self
end

function Statements.__index:visit(visitor)
   local statements = self.statements
   for i = 1, #statements do
      statements[i] = visitor(statements[i])
   end
   return self
end

function Statements.__index:visit_codegen(visitor)
   local node = visitor:visit_statements(self.start_position)
   local statements = self.statements
   for i = 1, #statements do
      node = visitor:visit_statements_statement(node, (visitor:visit(statements[i])))
   end
   node = visitor:visit_statements_end(node, self.end_position)
   return node
end

function Identifier.__index:init(start_position, end_position, identifier)
   self = Identifier:super().init(self, start_position, end_position)
   assert(identifier == nil or Class.type(identifier) == "string")
   self.identifier = identifier
   return self
end

function Identifier.__index:visit_codegen(visitor)
   return visitor:visit_identifier(self.start_position, self.end_position, self.identifier)
end

function ExpressionList.__index:init(start_position, end_position, list)
   self = ExpressionList:super().init(self, start_position, end_position)
   assert(list == nil or Class.type(list) == "table")
   self.list = list or {}
   return self
end

function ExpressionList.__index:add_expression(expression)
   assert(Expression:is_instance(expression))
   self.list[#self.list + 1] = expression
   return self
end

function ExpressionList.__index:visit(visitor)
   local list = self.list
   for i = 1, #list do
      list[i] = visitor(list[i])
   end
   return self
end

function ExpressionList.__index:visit_codegen(visitor)
   local node = visitor:visit_expression_list(self.start_position)
   local list = self.list
   for i = 1, #list do
      node = visitor:visit_expression_list_expression(node, (visitor:visit(list[i])))
   end
   node = visitor:visit_expression_list_end(node, self.end_position)
   return node
end

function Declaration.__index:init(start_position, end_position, identifier, attributes)
   self = Declaration:super().init(self, start_position, end_position)
   assert(identifier == nil or Identifier:is_instance(identifier))
   assert(attributes == nil or Class.type(attributes) == "table")
   self.identifier = identifier
   self.attributes = attributes or {}
   return self
end

function Declaration.__index:add_attribute(attribute)
   assert(Identifier:is_instance(attribute))
   self.attributes[#self.attributes + 1] = attribute
   return self
end

function Declaration.__index:visit(visitor)
   self.identifier = visitor(self.identifier)
   local attributes = self.attributes
   for i = 1, #attributes do
      attributes[i] = visitor(attributes[i])
   end
   return self
end

function Declaration.__index:visit_codegen(visitor)
   local node = visitor:visit_declaration(self.start_position, (visitor:visit(self.identifier)))
   local attributes = self.attributes
   for i = 1, #attributes do
      node = visitor:visit_declaration_attribute(node, (visitor:visit(attributes[i])))
   end
   node = visitor:visit_declaration_end(node, self.end_position)
   return node
end

function Empty.__index:visit_codegen(visitor)
   return visitor:visit_empty_statement(self.start_position, self.end_position)
end

function Assignment.__index:init(start_position, end_position, lvalues, rvalues)
   self = Assignment:super().init(self, start_position, end_position)
   assert(lvalues == nil or Class.type(lvalues) == "table")
   assert(rvalues == nil or ExpressionList:is_instance(rvalues))
   self.lvalues = lvalues or {}
   self.rvalues = rvalues
   return self
end

function Assignment.__index:add_lvalue(lvalue)
   assert(Expression:is_instance(lvalue))
   self.lvalues[#self.lvalues + 1] = lvalue
   return self
end

function Assignment.__index:set_rvalues(rvalues)
   assert(ExpressionList:is_instance(rvalues))
   self.rvalues = rvalues
   return self
end

function Assignment.__index:visit(visitor)
   local lvalues = self.lvalues
   for i = 1, #lvalues do
      lvalues[i] = visitor(lvalues[i])
   end
   self.rvalues = visitor(self.rvalues)
   return self
end

function Assignment.__index:visit_codegen(visitor)
   local lvalues = self.lvalues
   assert(#lvalues >= 1)
   local node = visitor:visit_assignment(self.start_position, (visitor:visit(lvalues[1])))
   for i = 2, #lvalues do
      node = visitor:visit_assignment_lvalue(node, (visitor:visit(lvalues[i])))
   end
   node = visitor:visit_assignment_end(node, self.end_position, (visitor:visit(self.rvalues)))
   return node
end

function Local.__index:init(start_position, end_position, declarations, init)
   self = Local:super().init(self, start_position, end_position)
   assert(declarations == nil or Class.type(declarations) == "table")
   assert(init == nil or ExpressionList:is_instance(init))
   self.declarations = declarations or {}
   self.init = init
   return self
end

function Local.__index:add_declaration(declaration)
   assert(Declaration:is_instance(declaration))
   self.declarations[#self.declarations + 1] = declaration
   return self
end

function Local.__index:set_init(init)
   assert(ExpressionList:is_instance(init))
   self.init = init
   return self
end

function Local.__index:visit(visitor)
   local declarations = self.declarations
   for i = 1, #declarations do
      declarations[i] = visitor(declarations[i])
   end
   self.init = visitor(self.init)
   return self
end

function Local.__index:visit_codegen(visitor)
   local node = visitor:visit_local(self.start_position)
   local declarations = self.declarations
   for i = 1, #declarations do
      node = visitor:visit_local_declaration(node, (visitor:visit(declarations[i])))
   end
   node = visitor:visit_local_end(node, self.end_position, (visitor:visit(self.init)))
   return node
end

function Variable.__index:init(start_position, end_position, identifier)
   self = Variable:super().init(self, start_position, end_position)
   assert(Identifier:is_instance(identifier))
   self.identifier = identifier
   return self
end

function Variable.__index:visit(visitor)
   self.identifier = visitor(self.identifier)
   return self
end

function Variable.__index:visit_codegen(visitor)
   return visitor:visit_variable(self.start_position, self.end_position, (visitor:visit(self.identifier)))
end

function Number.__index:init(start_position, end_position, value)
   self = Number:super().init(self, start_position, end_position)
   assert(Class.type(value) == "string")
   self.value = value
   return self
end

function Number.__index:visit_codegen(visitor)
   return visitor:visit_number(self.start_position, self.end_position, self.value)
end

function String.__index:init(start_position, end_position, value)
   self = String:super().init(self, start_position, end_position)
   assert(Class.type(value) == "string")
   self.value = value
   return self
end

function String.__index:visit_codegen(visitor)
   return visitor:visit_string(self.start_position, self.end_position, self.value)
end

function Table.__index:init(start_position, end_position, records)
   self = Table:super().init(self, start_position, end_position)
   assert(records == nil or Class.type(records) == "table")
   self.records = records or {}
   return self
end

function Table.__index:add_record(record)
   assert(Expression:is_instance(record) or Record:is_instance(record))
   self.records[#self.records + 1] = record
   return self
end

function Table.__index:visit_codegen(visitor)
   local table = visitor:visit_table(self.start_position)
   local records = self.records
   for i = 1, #records do
      table = visitor:visit_table_record(table, (visitor:visit(records[i])))
   end
   return visitor:visit_table_end(table, self.end_position)
end

function Record.__index:init(start_position, end_position, key, expr)
   self = Record:super().init(self, start_position, end_position)
   assert(Expression:is_instance(key))
   assert(Expression:is_instance(expr))
   self.key = key
   self.expr = expr
   return self
end

function Record.__index:visit_codegen(visitor)
   local key = visitor:visit(self.key)
   local expr = visitor:visit(self.expr)
   return visitor:visit_record(self.start_position, self.end_position, key, expr)
end

function Function.__index:init(start_position, end_position, is_method, arguments, is_vararg, body)
   self = Function:super().init(self, start_position, end_position)
   assert(is_method == nil or Class.type(is_method) == "boolean")
   assert(arguments == nil or Class.type(arguments) == "table")
   assert(is_vararg == nil or Class.type(is_vararg) == "boolean")
   assert(body == nil or Statements:is_instance(body))
   self.is_method = is_method and true or false
   self.arguments = arguments or {}
   self.is_vararg = is_vararg and true or false
   self.body = body
   return self
end

function Function.__index:add_argument(arg)
   assert(Declaration:is_instance(arg))
   self.arguments[#self.arguments + 1] = arg
   return self
end

function Function.__index:set_vararg()
   self.is_vararg = true
   return self
end

function Function.__index:set_body(body)
   assert(Statements:is_instance(body))
   self.body = body
   return self
end

function Function.__index:visit_codegen(visitor)
   local func = visitor:visit_function(self.start_position, self.is_method)
   local arguments = self.arguments
   for i = 1, #arguments do
      func = visitor:visit_function_parameter(func, (visitor:visit(arguments[i])))
   end
   if self.is_vararg then
      func = visitor:visit_function_vararg(func)
   end
   return visitor:visit_function_body(func, self.end_position, (visitor:visit(self.body)))
end

function Return.__index:init(start_position, end_position, returns)
   self = Return:super().init(self, start_position, end_position)
   assert(returns == nil or ExpressionList:is_instance(returns))
   self.returns = returns
   return self
end

function Return.__index:set_returns(returns)
   assert(ExpressionList:is_instance(returns))
   self.returns = returns
   return self
end

function Return.__index:visit_codegen(visitor)
   local ret = visitor:visit_return(self.start_position)
   return visitor:visit_return_end(ret, self.end_position, (visitor:visit(self.returns)))
end

function BinaryOp.__index:init(start_position, end_position, left, op, right)
   self = BinaryOp:super().init(self, start_position, end_position)
   assert(left == nil or Expression:is_instance(left))
   assert(op == nil or Class.type(op) == "string")
   assert(right == nil or Expression:is_instance(right))
   self.left = left
   self.op = op
   self.right = right
   return self
end

function BinaryOp.__index:set_right(right)
   assert(Expression:is_instance(right))
   self.right = right
   return self
end

function BinaryOp.__index:visit_codegen(visitor)
   local expr = visitor:visit_binary_op(self.start_position, visitor:visit(self.left), self.op)
   return visitor:visit_binary_op_end(expr, self.end_position, (visitor:visit(self.right)))
end

function UnaryOp.__index:init(start_position, end_position, op, expr)
   self = UnaryOp:super().init(self, start_position, end_position)
   assert(op == nil or Class.type(op) == "string")
   assert(expr == nil or Expression:is_instance(expr))
   self.op = op
   self.expr = expr
   return self
end

function UnaryOp.__index:set_expr(expr)
   assert(Expression:is_instance(expr))
   self.expr = expr
   return self
end

function UnaryOp.__index:visit_codegen(visitor)
   local expr = visitor:visit_unary_op(self.start_position, self.op)
   return visitor:visit_unary_op_end(expr, self.end_position, (visitor:visit(self.expr)))
end

function Call.__index:init(start_position, end_position, func, params)
   self = Call:super().init(self, start_position, end_position)
   assert(func == nil or Expression:is_instance(func))
   assert(params == nil or ExpressionList:is_instance(params))
   self.func = func
   self.params = params
   return self
end

function Call.__index:set_params(params)
   assert(ExpressionList:is_instance(params))
   self.params = params
   return self
end

function Call.__index:visit_codegen(visitor)
   local expr = visitor:visit_call(self.start_position, visitor:visit(self.func))
   return visitor:visit_call_end(expr, self.end_position, (visitor:visit(self.params)))
end

function MethodCall.__index:init(start_position, end_position, func, member, params)
   self = MethodCall:super().init(self, start_position, end_position)
   assert(func == nil or Expression:is_instance(func))
   assert(member == nil or Expression:is_instance(member))
   assert(params == nil or ExpressionList:is_instance(params))
   self.func = func
   self.member = member
   self.params = params
   return self
end

function MethodCall.__index:set_member(member)
   assert(Expression:is_instance(member))
   self.member = member
   return self
end

function MethodCall.__index:set_params(params)
   assert(ExpressionList:is_instance(params))
   self.params = params
   return self
end

function MethodCall.__index:visit_codegen(visitor)
   local expr = visitor:visit_method_call(self.start_position, (visitor:visit(self.func)))
   expr = visitor:visit_method_call_member(expr, (visitor:visit(self.member)))
   return visitor:visit_method_call_end(expr, self.end_position, (visitor:visit(self.params)))
end

function ExpressionStatement.__index:init(start_position, end_position, expr)
   self = ExpressionStatement:super().init(self, start_position, end_position)
   assert(expr == nil or Expression:is_instance(expr))
   self.expr = expr
   return self
end

function ExpressionStatement.__index:set_expr(expr)
   assert(Expression:is_instance(expr))
   self.expr = expr
   return self
end

function ExpressionStatement.__index:visit_codegen(visitor)
   local statement = visitor:visit_expression_statement(self.start_position)
   return visitor:visit_expression_statement_end(statement, self.end_position, (visitor:visit(self.expr)))
end

function Break.__index:visit_codegen(visitor)
   return visitor:visit_break(self.start_position, self.end_position)
end

function If.__index:init(start_position, end_position, pred, true_block, false_block)
   self = If:super().init(self, start_position, end_position)
   assert(pred == nil or Expression:is_instance(pred))
   assert(true_block == nil or Statements:is_instance(true_block))
   assert(false_block == nil or Statements:is_instance(false_block))
   self.pred = pred
   self.true_block = true_block
   self.false_block = false_block
   return self
end

function If.__index:set_pred(pred)
   assert(Expression:is_instance(pred))
   self.pred = pred
   return self
end

function If.__index:set_true_block(true_block)
   assert(Statements:is_instance(true_block))
   self.true_block = true_block
   return self
end

function If.__index:set_false_block(false_block)
   assert(Statements:is_instance(false_block))
   self.false_block = false_block
   return self
end

function If.__index:visit_codegen(visitor)
   local statement = visitor:visit_if(self.start_position)
   statement = visitor:visit_if_pred(statement, (visitor:visit(self.pred)))
   statement = visitor:visit_if_true(statement, (visitor:visit(self.true_block)))
   return visitor:visit_if_end(statement, self.end_position, (visitor:visit(self.false_block)))
end

function ForNum.__index:init(start_position, end_position, decl, start, limit, step, body)
   self = ForNum:super().init(self, start_position, end_position)
   assert(decl == nil or Declaration:is_instance(decl))
   assert(start == nil or Expression:is_instance(start))
   assert(limit == nil or Expression:is_instance(limit))
   assert(step == nil or Expression:is_instance(step))
   assert(body == nil or Statements:is_instance(body))
   self.decl = decl
   self.start = start
   self.limit = limit
   self.step = step
   self.body = body
   return self
end

function ForNum.__index:set_start(start)
   assert(Expression:is_instance(start))
   self.start = start
   return self
end

function ForNum.__index:set_limit(limit)
   assert(Expression:is_instance(limit))
   self.limit = limit
   return self
end

function ForNum.__index:set_step(step)
   assert(Expression:is_instance(step))
   self.step = step
   return self
end

function ForNum.__index:set_body(body)
   assert(Statements:is_instance(body))
   self.body = body
   return self
end

function ForNum.__index:visit_codegen(visitor)
   local loop = visitor:visit_for_num(self.start_position, (visitor:visit(self.decl)))
   loop = visitor:visit_for_num_start(loop, (visitor:visit(self.start)))
   loop = visitor:visit_for_num_limit(loop, (visitor:visit(self.limit)))
   loop = visitor:visit_for_num_step(loop, (visitor:visit(self.step)))
   return visitor:visit_for_num_end(loop, self.end_position, (visitor:visit(self.body)))
end

function ForIn.__index:init(start_position, end_position, decls, init, body)
   self = ForIn:super().init(self, start_position, end_position)
   assert(decls == nil or Class.type(decls) == "table")
   assert(init == nil or ExpressionList:is_instance(init))
   assert(body == nil or Statements:is_instance(body))
   self.decls = decls or {}
   self.init = init
   self.body = body
   return self
end

function ForIn.__index:add_decl(decl)
   assert(Declaration:is_instance(decl))
   self.decls[#self.decls + 1] = decl
   return self
end

function ForIn.__index:set_init(init)
   assert(ExpressionList:is_instance(init))
   self.init = init
   return self
end

function ForIn.__index:set_body(body)
   assert(Statements:is_instance(body))
   self.body = body
   return self
end

function ForIn.__index:visit_codegen(visitor)
   local decls = self.decls
   local loop = visitor:visit_for_in(self.start_position, (visitor:visit(decls[1])))
   for i = 2, #decls do
      loop = visitor:visit_for_in_var(loop, (visitor:visit(decls[i])))
   end
   loop = visitor:visit_for_in_init(loop, (visitor:visit(self.init)))
   return visitor:visit_for_in_end(loop, self.end_position, (visitor:visit(self.body)))
end

function While.__index:init(start_position, end_position, pred, body)
   self = While:super().init(self, start_position, end_position)
   assert(pred == nil or Expression:is_instance(pred))
   assert(body == nil or Statements:is_instance(body))
   self.pred = pred
   self.body = body
   return self
end

function While.__index:set_pred(pred)
   assert(Expression:is_instance(pred))
   self.pred = pred
   return self
end

function While.__index:set_body(body)
   assert(Statements:is_instance(body))
   self.body = body
   return self
end

function While.__index:visit_codegen(visitor)
   local loop = visitor:visit_while(self.start_position)
   loop = visitor:visit_while_pred(loop, (visitor:visit(self.pred)))
   return visitor:visit_while_end(loop, self.end_position, (visitor:visit(self.body)))
end

function Repeat.__index:init(start_position, end_position, body, pred)
   self = Repeat:super().init(self, start_position, end_position)
   assert(body == nil or Statements:is_instance(body))
   assert(pred == nil or Expression:is_instance(pred))
   self.body = body
   self.pred = pred
   return self
end

function Repeat.__index:set_body(body)
   assert(Statements:is_instance(body))
   self.body = body
   return self
end

function Repeat.__index:set_pred(pred)
   assert(Expression:is_instance(pred))
   self.pred = pred
   return self
end

function Repeat.__index:visit_codegen(visitor)
   local loop = visitor:visit_repeat(self.start_position)
   loop = visitor:visit_repeat_body(loop, (visitor:visit(self.body)))
   return visitor:visit_repeat_end(loop, self.end_position, (visitor:visit(self.pred)))
end

function Block.__index:init(start_position, end_position, body)
   self = Block:super().init(self, start_position, end_position)
   assert(body == nil or Statements:is_instance(body))
   self.body = body
   return self
end

function Block.__index:set_body(body)
   assert(Statements:is_instance(body))
   self.body = body
   return self
end

function Block.__index:visit_codegen(visitor)
   local loop = visitor:visit_block(self.start_position)
   return visitor:visit_block_end(loop, self.end_position, (visitor:visit(self.body)))
end

function True.__index:visit_codegen(visitor)
   return visitor:visit_true(self.start_position, self.end_position)
end

function False.__index:visit_codegen(visitor)
   return visitor:visit_false(self.start_position, self.end_position)
end

function Nil.__index:visit_codegen(visitor)
   return visitor:visit_nil(self.start_position, self.end_position)
end

function Varargs.__index:visit_codegen(visitor)
   return visitor:visit_varargs(self.start_position, self.end_position)
end

function LocalFunction.__index:init(start_position, end_position, decl, body)
   self = LocalFunction:super().init(self, start_position, end_position)
   assert(decl == nil or Declaration:is_instance(decl))
   assert(body == nil or Function:is_instance(body))
   self.decl = decl
   self.body = body
   return self
end

function LocalFunction.__index:set_decl(decl)
   assert(Declaration:is_instance(decl))
   self.decl = decl
   return self
end

function LocalFunction.__index:set_body(body)
   assert(Function:is_instance(body))
   self.body = body
   return self
end

function LocalFunction.__index:visit_codegen(visitor)
   local func = visitor:visit_local_function(self.start_position)
   func = visitor:visit_local_function_declaration(func, (visitor:visit(self.decl)))
   return visitor:visit_local_function_end(func, self.end_position, (visitor:visit(self.body)))
end

function Label.__index:init(start_position, end_position, name)
   self = Label:super().init(self, start_position, end_position)
   assert(name == nil or Identifier:is_instance(name))
   self.name = name
   return self
end

function Label.__index:visit_codegen(visitor)
   return visitor:visit_label(self.start_position, self.end_position, (visitor:visit(self.name)))
end

function Goto.__index:init(start_position, end_position, name)
   self = Goto:super().init(self, start_position, end_position)
   assert(name == nil or Identifier:is_instance(name))
   self.name = name
   return self
end

function Goto.__index:visit_codegen(visitor)
   return visitor:visit_goto(self.start_position, self.end_position, (visitor:visit(self.name)))
end

return Ast
