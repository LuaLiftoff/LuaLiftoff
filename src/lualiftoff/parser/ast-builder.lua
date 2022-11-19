-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require"lualiftoff.util.class"
local Ast = require"lualiftoff.parser.ast"
local error = require"lualiftoff.lua.error"

local AstBuilder = Class"AstBuilder"

local Statement = Ast.Statement
local Expression = Ast.Expression

function AstBuilder.__index:visit_statements(position)
   return Ast.Statements(position)
end

function AstBuilder.__index:visit_statements_statement(statements, statement)
   return statements:add_statement(statement)
end

function AstBuilder.__index:visit_statements_end(statements, position)
   return statements:set_end(position)
end

function AstBuilder.__index:visit_identifier(start_position, end_position, identifier)
   return Ast.Identifier(start_position, end_position, identifier)
end

function AstBuilder.__index:visit_variable(start_position, end_position, identifier)
   return Expression.Variable(start_position, end_position, identifier)
end

function AstBuilder.__index:visit_number(start_position, end_position, number)
   return Expression.Number(start_position, end_position, number)
end

function AstBuilder.__index:visit_assignment(position, expr)
   return Statement.Assignment(position, nil, {expr})
end

function AstBuilder.__index:visit_assignment_lvalue(assignment, expr)
   return assignment:add_lvalue(expr)
end

function AstBuilder.__index:visit_assignment_end(assignment, position, rvalues)
   return assignment:set_rvalues(rvalues):set_end(position)
end


function AstBuilder.__index:visit_expression_list(position)
   return Ast.ExpressionList(position)
end

function AstBuilder.__index:visit_expression_list_expression(list, expr)
   return list:add_expression(expr)
end

function AstBuilder.__index:visit_expression_list_end(list, position)
   return list:set_end(position)
end


function AstBuilder.__index:visit_local(position)
   return Statement.Local(position)
end

function AstBuilder.__index:visit_local_declaration(loc, declaration)
   return loc:add_declaration(declaration)
end

function AstBuilder.__index:visit_local_end(loc, position, init)
   return loc:set_init(init):set_end(position)
end


function AstBuilder.__index:visit_declaration(position, identifier)
   return Ast.Declaration(position, position, identifier)
end

function AstBuilder.__index:visit_declaration_attribute(declaration, attribute)
   return declaration:add_attribute(attribute)
end

function AstBuilder.__index:visit_declaration_end(declaration, position)
   return declaration:set_end(position)
end

function AstBuilder.__index:visit_empty_statement(start_position, end_position)
   return Statement.Empty(start_position, end_position)
end

function AstBuilder.__index:visit_table(start_position)
   return Expression.Table(start_position)
end

function AstBuilder.__index:visit_table_record(table, record)
   return table:add_record(record)
end

function AstBuilder.__index:visit_table_end(table, end_position)
   return table:set_end(end_position)
end

function AstBuilder.__index:visit_record(start_position, end_position, key, expr)
   return Ast.Record(start_position, end_position, key, expr)
end

function AstBuilder.__index:visit_string(start_position, end_position, value)
   return Expression.String(start_position, end_position, value)
end


function AstBuilder.__index:visit_function(start_position, is_method)
   return Expression.Function(start_position, nil, is_method)
end

function AstBuilder.__index:visit_function_parameter(func, arg)
   return func:add_argument(arg)
end

function AstBuilder.__index:visit_function_vararg(func)
   return func:set_vararg()
end

function AstBuilder.__index:visit_function_body(func, end_position, body)
   return func:set_body(body):set_end(end_position)
end

function AstBuilder.__index:visit_return(start_position)
   return Statement.Return(start_position)
end

function AstBuilder.__index:visit_return_end(ret, end_position, list)
   return ret:set_returns(list):set_end(end_position)
end

function AstBuilder.__index:visit_binary_op(start_position, left, op)
   return Expression.BinaryOp(start_position, nil, left, op)
end

function AstBuilder.__index:visit_binary_op_end(expr, end_position, right)
   return expr:set_right(right):set_end(end_position)
end

function AstBuilder.__index:visit_unary_op(start_position, op)
   return Expression.UnaryOp(start_position, nil, op)
end

function AstBuilder.__index:visit_unary_op_end(expr, end_position, vexpr)
   return expr:set_expr(vexpr):set_end(end_position)
end

function AstBuilder.__index:visit_call(start_position, func)
   return Expression.Call(start_position, nil, func)
end

function AstBuilder.__index:visit_call_end(call, end_position, params)
   return call:set_params(params):set_end(end_position)
end

function AstBuilder.__index:visit_method_call(start_position, func)
   return Expression.MethodCall(start_position, nil, func)
end

function AstBuilder.__index:visit_method_call_member(call, member)
   return call:set_member(member)
end

function AstBuilder.__index:visit_method_call_end(call, end_position, params)
   return call:set_params(params):set_end(end_position)
end

function AstBuilder.__index:visit_expression_statement(start_position)
   return Statement.ExpressionStatement(start_position)
end

function AstBuilder.__index:visit_expression_statement_end(statement, end_position, expr)
   return statement:set_expr(expr):set_end(end_position)
end

function AstBuilder.__index:visit_break(start_position, end_position)
   return Statement.Break(start_position, end_position)
end

function AstBuilder.__index:visit_if(start_position)
   return Statement.If(start_position)
end

function AstBuilder.__index:visit_if_pred(statement, pred)
   return statement:set_pred(pred)
end

function AstBuilder.__index:visit_if_true(statement, true_block)
   return statement:set_true_block(true_block)
end

function AstBuilder.__index:visit_if_end(statement, end_position, false_block)
   return statement:set_false_block(false_block):set_end(end_position)
end

function AstBuilder.__index:visit_for_num(start, decl)
   return Statement.ForNum(start, nil, decl)
end

function AstBuilder.__index:visit_for_num_start(loop, start)
   return loop:set_start(start)
end

function AstBuilder.__index:visit_for_num_limit(loop, limit)
   return loop:set_limit(limit)
end

function AstBuilder.__index:visit_for_num_step(loop, step)
   return loop:set_step(step)
end

function AstBuilder.__index:visit_for_num_end(loop, end_position, statements)
   return loop:set_body(statements):set_end(end_position)
end

function AstBuilder.__index:visit_for_num(start, decl)
   return Statement.ForNum(start, nil, decl)
end

function AstBuilder.__index:visit_for_num_start(loop, start)
   return loop:set_start(start)
end

function AstBuilder.__index:visit_for_num_limit(loop, limit)
   return loop:set_limit(limit)
end

function AstBuilder.__index:visit_for_num_step(loop, step)
   return loop:set_step(step)
end

function AstBuilder.__index:visit_for_num_end(loop, end_position, statements)
   return loop:set_body(statements):set_end(end_position)
end

function AstBuilder.__index:visit_for_in(start, decl)
   return Statement.ForIn(start, nil, {decl})
end

function AstBuilder.__index:visit_for_in_var(loop, decl)
   return loop:add_decl(decl)
end

function AstBuilder.__index:visit_for_in_init(loop, list)
   return loop:set_init(list)
end

function AstBuilder.__index:visit_for_in_end(loop, end_position, body)
   return loop:set_body(body):set_end(end_position)
end

function AstBuilder.__index:visit_while(start_position)
   return Statement.While(start_position)
end

function AstBuilder.__index:visit_while_pred(loop, expr)
   return loop:set_pred(expr)
end

function AstBuilder.__index:visit_while_end(loop, end_position, body)
   return loop:set_body(body):set_end(end_position)
end


function AstBuilder.__index:visit_repeat(start_position)
   return Statement.Repeat(start_position)
end

function AstBuilder.__index:visit_repeat_body(loop, body)
   return loop:set_body(body)
end

function AstBuilder.__index:visit_repeat_end(loop, end_position, pred)
   return loop:set_pred(pred):set_end(end_position)
end

function AstBuilder.__index:visit_block(start_position)
   return Statement.Block(start_position)
end

function AstBuilder.__index:visit_block_end(block, end_position, body)
   return block:set_body(body):set_end(end_position)
end

function AstBuilder.__index:visit_true(start, end_position)
   return Expression.True(start, end_position)
end

function AstBuilder.__index:visit_false(start, end_position)
   return Expression.False(start, end_position)
end

function AstBuilder.__index:visit_nil(start, end_position)
   return Expression.Nil(start, end_position)
end

function AstBuilder.__index:visit_varargs(start, end_position)
   return Expression.Varargs(start, end_position)
end

function AstBuilder.__index:visit_local_function(start)
   return Statement.LocalFunction(start)
end

function AstBuilder.__index:visit_local_function_declaration(func, decl)
   return func:set_decl(decl)
end

function AstBuilder.__index:visit_local_function_end(func, end_position, body)
   return func:set_body(body):set_end(end_position)
end

function AstBuilder.__index:visit_label(start, end_position, name)
   return Statement.Label(start, end_position, name)
end

function AstBuilder.__index:visit_goto(start, end_position, name)
   return Statement.Goto(start, end_position, name)
end


function AstBuilder.__index:visit_error(msg)
   error.error(msg)
end

return AstBuilder
