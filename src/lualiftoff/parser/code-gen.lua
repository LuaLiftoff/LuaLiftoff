-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

-- luacheck: no unused

local Class = require"lualiftoff.util.class"
local Ast = require"lualiftoff.parser.ast"
local Opcode = require"lualiftoff.parser.opcode"
local error = require"lualiftoff.lua.error"

local CodeGen = Class"CodeGen"

local Statement = Ast.Statement
local Expression = Ast.Expression

function CodeGen.__index:init()
   self = CodeGen:super().init(self)
   self.expr_kind = 0
   self.expr_value = false
   self.expr_index = false
   self.code = {}
   return self
end

function CodeGen.__index:visit_statements(position)
end

function CodeGen.__index:visit_statements_statement(statements, statement)
end

function CodeGen.__index:visit_statements_end(statements, position)
end

function CodeGen.__index:visit_identifier(start_position, end_position, identifier)
   return identifier
end

function CodeGen.__index:visit_variable(start_position, end_position, identifier)
   self.expr_kind = 1
   self.expr_value = identifier
end

function CodeGen.__index:visit_number(start_position, end_position, number)
   self.expr_kind = 3
   self.expr_value = number
end

function CodeGen.__index:visit_assignment(position, expr)
   return {{kind = self.expr_kind, value = self.expr_value, index = self.expr_index}}
end

function CodeGen.__index:visit_assignment_lvalue(assignment, expr)
   assignment[#assignment+1] = {kind = self.expr_kind, value = self.expr_value, index = self.expr_index}
   return assignment
end

function CodeGen.__index:visit_assignment_end(assignment, position, rvalues)

end

function CodeGen.__index:emit(op, arg)
   local code = self.code
   local idx = #code+1
   code[idx] = op * 256 + arg
   return idx
end

function CodeGen.__index:to_acc()
   if self.expr_kind == 1 then
      self.emit(Opcode.GET, self.expr_value)
   elseif self.expr_kind == 2 then
      self.emit(Opcode.GET_UPVAL, self.expr_value)
   elseif self.expr_kind == 3 then
      self.emit(Opcode.GET_CONST, self.expr_value)
   -- elseif self.expr_kind == 4 then
      -- TODO
   end
   -- TODO
end

function CodeGen.__index:to_next_reg()
   -- TODO
end

function CodeGen.__index:visit_expression_list(position)
   self.expr_kind = 0
   return 0
end

function CodeGen.__index:visit_expression_list_expression(list, expr)
   self:to_next_reg()
   return list + 1
end

function CodeGen.__index:visit_expression_list_end(list, position)
   return list
end


function CodeGen.__index:visit_local(position)
   return 0
end

function CodeGen.__index:visit_local_declaration(loc, declaration)
   -- TODO
   return loc + 1
end

function CodeGen.__index:visit_local_end(loc, position, init)
   -- TODO
end


function CodeGen.__index:visit_declaration(position, identifier)
   -- TODO
end

function CodeGen.__index:visit_declaration_attribute(declaration, attribute)
   -- TODO
end

function CodeGen.__index:visit_declaration_end(declaration, position)
   -- TODO
end

function CodeGen.__index:visit_empty_statement(start_position, end_position)
end

function CodeGen.__index:visit_table(start_position)
   return Expression.Table(start_position)
end

function CodeGen.__index:visit_table_record(table, record)
   return table:add_record(record)
end

function CodeGen.__index:visit_table_end(table, end_position)
   return table:set_end(end_position)
end

function CodeGen.__index:visit_record(start_position, end_position, key, expr)
   return Ast.Record(start_position, end_position, key, expr)
end

function CodeGen.__index:visit_string(start_position, end_position, value)
   self.expr_kind = 3
   self.expr_value = value
end


function CodeGen.__index:visit_function(start_position, is_method)
   self.frame = {
      parent = self.frame,
   }
end

function CodeGen.__index:visit_function_parameter(func, arg)
end

function CodeGen.__index:visit_function_vararg(func)
   self.frame.is_vararg = true
end

function CodeGen.__index:visit_function_body(func, end_position, body)
   -- TODO
   self.frame = self.frame.parent
end

function CodeGen.__index:visit_return(start_position)
   -- TODO
end

function CodeGen.__index:visit_return_end(ret, end_position, list)
   -- TODO
end

function CodeGen.__index:visit_binary_op(start_position, left, op)
   left = self:to_next_reg()
   return left
end

function CodeGen.__index:visit_binary_op_end(left, end_position, right)
   self:to_acc()
   -- TODO

end

function CodeGen.__index:visit_unary_op(start_position, op)
   return op
end

function CodeGen.__index:visit_unary_op_end(op, end_position, expr)
   self:to_acc()
   -- TODO
end

function CodeGen.__index:visit_call(start_position, func)
   self:to_next_reg()
   -- TODO
end

function CodeGen.__index:visit_call_end(call, end_position, params)
   -- TODO
end

function CodeGen.__index:visit_method_call(start_position, func)
   self:to_next_reg()
   -- TODO
end

function CodeGen.__index:visit_method_call_member(call, member)
   self:to_acc()
   -- TODO
end

function CodeGen.__index:visit_method_call_end(call, end_position, params)
   -- TODO
end

function CodeGen.__index:visit_expression_statement(start_position)
   -- TODO
end

function CodeGen.__index:visit_expression_statement_end(statement, end_position, expr)
   -- TODO
end

function CodeGen.__index:visit_break(start_position, end_position)
   return Statement.Break(start_position, end_position)
end

function CodeGen.__index:visit_if(start_position)
   return Statement.If(start_position)
end

function CodeGen.__index:visit_if_pred(statement, pred)
   return statement:set_pred(pred)
end

function CodeGen.__index:visit_if_true(statement, true_block)
   return statement:set_true_block(true_block)
end

function CodeGen.__index:visit_if_end(statement, end_position, false_block)
   return statement:set_false_block(false_block):set_end(end_position)
end

function CodeGen.__index:visit_for_num(start, decl)
   return Statement.ForNum(start, nil, decl)
end

function CodeGen.__index:visit_for_num_start(loop, start)
   return loop:set_start(start)
end

function CodeGen.__index:visit_for_num_limit(loop, limit)
   return loop:set_limit(limit)
end

function CodeGen.__index:visit_for_num_step(loop, step)
   return loop:set_step(step)
end

function CodeGen.__index:visit_for_num_end(loop, end_position, statements)
   return loop:set_body(statements):set_end(end_position)
end

function CodeGen.__index:visit_for_num(start, decl)
   return Statement.ForNum(start, nil, decl)
end

function CodeGen.__index:visit_for_num_start(loop, start)
   return loop:set_start(start)
end

function CodeGen.__index:visit_for_num_limit(loop, limit)
   return loop:set_limit(limit)
end

function CodeGen.__index:visit_for_num_step(loop, step)
   return loop:set_step(step)
end

function CodeGen.__index:visit_for_num_end(loop, end_position, statements)
   return loop:set_body(statements):set_end(end_position)
end

function CodeGen.__index:visit_for_in(start, decl)
   return Statement.ForIn(start, nil, {decl})
end

function CodeGen.__index:visit_for_in_var(loop, decl)
   return loop:add_decl(decl)
end

function CodeGen.__index:visit_for_in_init(loop, list)
   return loop:set_init(list)
end

function CodeGen.__index:visit_for_in_end(loop, end_position, body)
   return loop:set_body(body):set_end(end_position)
end

function CodeGen.__index:visit_while(start_position)
   return Statement.While(start_position)
end

function CodeGen.__index:visit_while_pred(loop, expr)
   return loop:set_pred(expr)
end

function CodeGen.__index:visit_while_end(loop, end_position, body)
   return loop:set_body(body):set_end(end_position)
end


function CodeGen.__index:visit_repeat(start_position)
   return Statement.Repeat(start_position)
end

function CodeGen.__index:visit_repeat_body(loop, body)
   return loop:set_body(body)
end

function CodeGen.__index:visit_repeat_end(loop, end_position, pred)
   return loop:set_pred(pred):set_end(end_position)
end

function CodeGen.__index:visit_block(start_position)
   return Statement.Block(start_position)
end

function CodeGen.__index:visit_block_end(block, end_position, body)
   return block:set_body(body):set_end(end_position)
end

function CodeGen.__index:visit_true(start, end_position)
   return Expression.True(start, end_position)
end

function CodeGen.__index:visit_false(start, end_position)
   return Expression.False(start, end_position)
end

function CodeGen.__index:visit_nil(start, end_position)
   return Expression.Nil(start, end_position)
end

function CodeGen.__index:visit_varargs(start, end_position)
   return Expression.Varargs(start, end_position)
end

function CodeGen.__index:visit_local_function(start)
   return Statement.LocalFunction(start)
end

function CodeGen.__index:visit_local_function_declaration(func, decl)
   return func:set_decl(decl)
end

function CodeGen.__index:visit_local_function_end(func, end_position, body)
   return func:set_body(body):set_end(end_position)
end

function CodeGen.__index:visit_label(start, end_position, name)
   return Statement.Label(start, end_position, name)
end

function CodeGen.__index:visit_goto(start, end_position, name)
   return Statement.Goto(start, end_position, name)
end


function CodeGen.__index:visit_error(msg)
   error.error(msg)
end

return CodeGen
