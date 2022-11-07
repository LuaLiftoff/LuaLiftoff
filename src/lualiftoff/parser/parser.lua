-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require "lualiftoff.util.class"

local Parser = Class "Parser"

local function make_call_method(name)
   return function(obj, ...)
      return obj[name](obj, ...)
   end
end

local function is_end(ctx, parser)
   return parser:is_identifier_value("end")
end

local ChunkBlockContext = { name = "Chunk", ends = is_end }
local FunctionBlockContext = { name = "Function", ends = is_end }
local DoBlockContext = { name = "Do", ends = is_end }
local WhileBlockContext = { name = "While", ends = is_end }
local ForBlockContext = { name = "For", ends = is_end }
local RepeatBlockContext = { name = "Repeat", ends = function(ctx, parser) return parser:is_identifier_value("until") end }
local IfBlockContext = { name = "If",
   ends = function(ctx, parser) return parser:is_identifier_value("end") or parser:is_identifier_value("else") or
       parser:is_identifier_value("elseif") end }
local ElseBlockContext = { name = "Else", ends = is_end }

local default_statement_handlers = {
   identifier = function(parser)
      local handler = parser.statement_handler_keywords[parser.lexer.value] or parser.parse_expression_statement
      return handler(parser)
   end,
   ["::"] = make_call_method("parse_label"),
   [";"] = make_call_method("parse_empty_statement"),
   ["eof"] = function() return nil end
}

local default_statement_handler_keywords = {
   ["if"] = make_call_method("parse_if"),
   ["else"] = make_call_method("parse_else"),
   ["elseif"] = make_call_method("parse_elseif"),
   ["do"] = make_call_method("parse_do"),
   ["for"] = make_call_method("parse_for"),
   ["while"] = make_call_method("parse_while"),
   ["repeat"] = make_call_method("parse_repeat"),
   ["function"] = make_call_method("parse_function_statement"),
   ["local"] = make_call_method("parse_local"),
   ["goto"] = make_call_method("parse_goto"),
   ["return"] = make_call_method("parse_return"),
   ["break"] = make_call_method("parse_break"),
   ["end"] = make_call_method("parse_end"),
   ["until"] = make_call_method("parse_until")
}

local function make_parse_unary_op(name)
   return function(parser, priority)
      local own_priority = parser.prefix_priority[name]
      if own_priority > priority then
         priority = own_priority
      end
      return parser:parse_unary_op(name, priority)
   end
end

local default_prefix_operator_handlers = {
   identifier = function(parser, priority)
      local handler = parser.prefix_operator_keywords[parser.lexer.value] or parser.parse_variable
      return handler(parser, priority)
   end,
   number = make_call_method("parse_number"),
   ["."] = make_call_method("parse_number"),
   string = make_call_method("parse_string"),
   ["-"] = make_parse_unary_op("-"),
   ["~"] = make_parse_unary_op("~"),
   ["#"] = make_parse_unary_op("#"),
   ["{"] = make_call_method("parse_table"),
   ["("] = make_call_method("parse_group"),
   ["..."] = make_call_method("parse_varargs")
}

local default_prefix_operator_keywords = {
   ["not"] = make_parse_unary_op("not"),
   ["true"] = make_call_method("parse_true"),
   ["false"] = make_call_method("parse_false"),
   ["nil"] = make_call_method("parse_nil"),
   ["function"] = make_call_method("parse_function_expression")
}

local function make_parse_binary_op(name)
   return function(parser, start, expr, priority, allow_as_statement)
      local own_priority = parser.operator_priority[name]
      if own_priority < 0 then
         own_priority = -own_priority
         if priority > own_priority then return expr, false, allow_as_statement end
      else
         if priority >= own_priority then return expr, false, allow_as_statement end
      end
      return parser:parse_binary_op(start, expr, name, own_priority)
   end
end

local default_operator_handlers = {
   identifier = function(parser, start, expr, priority, allow_as_statement)
      local handler = parser.operator_keywords[parser.lexer.value]
      if not handler then return expr, false, allow_as_statement end
      return handler(parser, start, expr, priority, allow_as_statement)
   end,
   ["."] = make_call_method("parse_field"),
   ["["] = make_call_method("parse_index"),
   string = make_call_method("parse_call_string"),
   ["{"] = make_call_method("parse_call_table"),
   ["("] = make_call_method("parse_call"),
   [":"] = make_call_method("parse_method"),
   ["+"] = make_parse_binary_op("+"),
   ["-"] = make_parse_binary_op("-"),
   ["*"] = make_parse_binary_op("*"),
   ["/"] = make_parse_binary_op("/"),
   ["//"] = make_parse_binary_op("//"),
   ["^"] = make_parse_binary_op("^"),
   ["%"] = make_parse_binary_op("%"),
   ["&"] = make_parse_binary_op("&"),
   ["|"] = make_parse_binary_op("|"),
   ["~"] = make_parse_binary_op("~"),
   ["<<"] = make_parse_binary_op("<<"),
   [">>"] = make_parse_binary_op(">>"),
   ["=="] = make_parse_binary_op("=="),
   ["~="] = make_parse_binary_op("~="),
   [">="] = make_parse_binary_op(">="),
   [">"] = make_parse_binary_op(">"),
   ["<="] = make_parse_binary_op("<="),
   ["<"] = make_parse_binary_op("<"),
   [".."] = make_parse_binary_op("..")
}

local default_operator_keywords = {
   ["and"] = make_parse_binary_op("and"),
   ["or"] = make_parse_binary_op("or")
}

local default_local_handlers = {
   identifier = function(parser, start)
      local handler = parser.local_keywords[parser.lexer.value]
      if not handler then return parser:parse_local_default(start) end
      return handler(parser, start)
   end,
}

local default_local_keywords = {
   ["function"] = make_call_method("parse_local_function")
}

local default_operator_priority = {
   ["or"] = 10,
   ["and"] = 20,
   ["=="] = 30,
   ["~="] = 30,
   [">="] = 30,
   [">"] = 30,
   ["<="] = 30,
   ["<"] = 30,
   ["|"] = 40,
   ["~"] = 50,
   ["&"] = 60,
   ["<<"] = 70,
   [">>"] = 70,
   [".."] = -80,
   ["+"] = 90,
   ["-"] = 90,
   ["*"] = 100,
   ["/"] = 100,
   ["//"] = 100,
   ["%"] = 100,
   ["^"] = -120,
}

local default_prefix_priority = {
   ["-"] = 110,
   ["~"] = 110,
   ["#"] = 110,
   ["not"] = 110,
}

local default_reserved_identifiers = {
   ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true,
   ["false"] = true, ["for"] = true, ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
   ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true, ["return"] = true,
   ["then"] = true, ["true"] = true, ["until"] = true, ["while"] = true
}

function Parser.__index:init(lexer, visitor)
   self.lexer = lexer
   self.visitor = visitor
   self.statement_handlers = default_statement_handlers
   self.statement_handler_keywords = default_statement_handler_keywords
   self.prefix_operator_handler = default_prefix_operator_handlers
   self.prefix_operator_keywords = default_prefix_operator_keywords
   self.operator_handler = default_operator_handlers
   self.operator_keywords = default_operator_keywords
   self.local_handlers = default_local_handlers
   self.local_keywords = default_local_keywords
   self.last_end_position_value = 1
   self.block_context = ChunkBlockContext
   self.reserved_identifiers = default_reserved_identifiers
   self.operator_priority = default_operator_priority
   self.prefix_priority = default_prefix_priority
   return self
end

function Parser.__index:start_position()
   return self.lexer.start
end

function Parser.__index:last_end_position()
   return self.last_end_position_value
end

function Parser.__index:next_token()
   self.token = self.lexer:next_token()
end

function Parser.__index:next_token_save_end()
   self:next_token()
   self.last_end_position_value = self:start_position()
end

function Parser.__index:skip_spaces()
   while self.token == "space" or self.token == "comment" do
      self:next_token()
   end
end

function Parser.__index:next_non_space_token()
   self:next_token_save_end()
   self:skip_spaces()
end

function Parser.__index:error(message)
   return self.visitor:visit_error(message)
end

function Parser.__index:is_token(what)
   return self.token == what
end

function Parser.__index:is_eof()
   return self:is_token("eof")
end

function Parser.__index:is_identifier()
   return self:is_token("identifier")
end

function Parser.__index:is_identifier_value(what)
   return self:is_identifier() and self.lexer.value == what
end

function Parser.__index:is_non_reserved_identifier()
   return self:is_identifier() and not self.reserved_identifiers[self.lexer.value]
end

function Parser.__index:expect_token(what)
   if self:is_token(what) then
      self:next_non_space_token()
      return
   end
   self:error(string.format("Expected %q but got ", what))
end

function Parser.__index:expect_keyword(what)
   if self:is_identifier_value(what) then
      self:next_non_space_token()
      return
   end
   self:error(string.format("Expected %q but got ", what))
end

function Parser.__index:parse_identifier_value()
   if not self:is_non_reserved_identifier() then
      self:error("Identifier expected")
      return nil
   end
   local value = self.lexer.value
   self:next_non_space_token()
   return value
end

function Parser.__index:parse_identifier()
   local start = self:start_position()
   local value = self:parse_identifier_value()
   return (self.visitor:visit_identifier(start, self:last_end_position(), value))
end

function Parser.__index:parse_identifier_string()
   local start = self:start_position()
   local value = self:parse_identifier_value()
   return (self.visitor:visit_string(start, self:last_end_position(), value))
end

function Parser.__index:parse_assignment(start, expr)
   local assignment = self.visitor:visit_assignment(start, expr)
   while self:is_token(",") do
      self:next_non_space_token()
      expr = self:parse_expression()
      assignment = self.visitor:visit_assignment_lvalue(assignment, expr)
   end
   self:expect_token("=")
   local list = self:parse_expression_list()
   return self.visitor:visit_assignment_end(assignment, self:last_end_position(), list)
end

function Parser.__index:parse_number()
   local start = self:start_position()
   local number = ""
   local exp = "e"
   if self:is_token("number") then
      number = self.lexer.value
      if "0x" == string.lower(string.sub(number, 1, 2)) then
         exp = "p"
      end
      self:next_token_save_end()
   end
   if self:is_token(".") then
      number = number .. "."
      self:next_token_save_end()
      if self:is_token("number") then
         number = number .. self.lexer.value
         self:next_token_save_end()
      end
   end
   if exp == string.lower(string.sub(number, -1)) then
      if self:is_token("+") then
         number = number .. "+"
         self:next_token_save_end()
      elseif self:is_token("-") then
         number = number .. "-"
         self:next_token_save_end()
      end
      if self:is_token("number") then
         number = number .. self.lexer.value
         self:next_token_save_end()
      end
   end
   self:skip_spaces()
   return self.visitor:visit_number(start, self:last_end_position(), number), false
end

function Parser.__index:parse_string()
   local value = self.lexer.value
   local start = self:start_position()
   self:next_non_space_token()
   return self.visitor:visit_string(start, self:last_end_position(), value), false
end

function Parser.__index:parse_true()
   local start = self:start_position()
   self:next_non_space_token()
   return self.visitor:visit_true(start, self:last_end_position()), false
end

function Parser.__index:parse_false()
   local start = self:start_position()
   self:next_non_space_token()
   return self.visitor:visit_false(start, self:last_end_position()), false
end

function Parser.__index:parse_nil()
   local start = self:start_position()
   self:next_non_space_token()
   return self.visitor:visit_nil(start, self:last_end_position()), false
end

function Parser.__index:parse_variable()
   local start = self:start_position()
   local ident = self:parse_identifier()
   return self.visitor:visit_variable(start, self:last_end_position(), ident), false
end

function Parser.__index:parse_table()
   local table = self.visitor:visit_table(self:start_position())
   self:next_non_space_token()
   while true do
      local start = self:start_position()
      local expr
      if self:is_token("}") then
         break
      elseif self:is_non_reserved_identifier() then
         local name = self.lexer.value
         self:next_non_space_token()
         local endpos = self:last_end_position()
         if self:is_token("=") then
            local key = self.visitor:visit_string(start, endpos, name)
            self:next_non_space_token()
            expr = self:parse_expression()
            expr = self.visitor:visit_record(start, self:last_end_position(), key, expr)
         else
            local key = self.visitor:visit_identifier(start, endpos, name)
            expr = self.visitor:visit_variable(start, endpos, key)
            expr = self:parse_rexpression(expr, 0, false)
         end
      elseif self:is_token("[") then
         self:next_non_space_token()
         local key = self:parse_expression()
         self:expect_token("]")
         self:expect_token("=")
         expr = self:parse_expression()
         expr = self.visitor:visit_record(start, self:last_end_position(), key, expr)
      elseif self:is_eof() then
         break
      else
         expr = self:parse_expression()
      end
      table = self.visitor:visit_table_record(table, expr)
      if not self:is_token(",") and not self:is_token(";") then
         break
      end
      self:next_non_space_token()
   end
   self:expect_token("}")
   return self.visitor:visit_table_end(table, self:last_end_position()), false
end

function Parser.__index:parse_return()
   local ret = self.visitor:visit_return(self:start_position())
   self:next_non_space_token()
   local returns
   if self.block_context:ends(self) or self:is_token(";") then
      local pos = self:start_position()
      local list = self.visitor:visit_expression_list(pos)
      returns = self.visitor:visit_expression_list_end(list, pos)
   else
      returns = self:parse_expression_list()
   end
   if self:is_token(";") then
      self:next_non_space_token()
   end
   if not self.block_context:ends(self) then
      self:error("Return not at end of block")
   end
   return self.visitor:visit_return_end(ret, self:last_end_position(), returns)
end

function Parser.__index:parse_break()
   local start = self:start_position()
   self:next_non_space_token()
   return self.visitor:visit_break(start, self:last_end_position())
end

function Parser.__index:parse_group()
   local group = self.visitor:visit_unary_op(self:start_position(), "(")
   self:next_non_space_token()
   local expr = self:parse_expression()
   self:expect_token(")")
   return self.visitor:visit_unary_op_end(group, self:last_end_position(), expr), false
end

function Parser.__index:parse_varargs()
   local start = self:start_position()
   self:next_non_space_token()
   return self.visitor:visit_varargs(start, self:last_end_position())
end

function Parser.__index:parse_unknown_lexpression(priority)
   return self:error(string.format("Unexpected token %q", self.token)), true
end

function Parser.__index:parse_unary_op(name, priority)
   local expr = self.visitor:visit_unary_op(self:start_position(), name)
   self:next_non_space_token()
   local value = self:parse_expression(priority)
   expr = self.visitor:visit_unary_op_end(expr, self:last_end_position(), value)
   return expr, false
end

function Parser.__index:parse_lexpression(priority)
   local handler = self.prefix_operator_handler[self.token] or self.parse_unknown_lexpression
   return handler(self, priority)
end

function Parser.__index:parse_binary_op(start, expr, name, priority)
   expr = self.visitor:visit_binary_op(start, expr, name)
   self:next_non_space_token()
   local right = self:parse_expression(priority)
   expr = self.visitor:visit_binary_op_end(expr, self:last_end_position(), right)
   return expr, true, false
end

function Parser.__index:parse_field(start, expr)
   expr = self.visitor:visit_binary_op(start, expr, "[")
   self:next_non_space_token()
   local key = self:parse_identifier_string()
   expr = self.visitor:visit_binary_op_end(expr, self:last_end_position(), key)
   return expr, true, false
end

function Parser.__index:parse_index(start, expr)
   expr = self.visitor:visit_binary_op(start, expr, "[")
   self:next_non_space_token()
   local index = self:parse_expression()
   self:expect_token("]")
   expr = self.visitor:visit_binary_op_end(expr, self:last_end_position(), index)
   return expr, true, false
end

function Parser.__index:parse_call_params_string()
   local list = self.visitor:visit_expression_list(self:start_position())
   local param = self:parse_string()
   list = self.visitor:visit_expression_list_expression(list, param)
   local params = self.visitor:visit_expression_list_end(list, self:last_end_position())
   return params
end

function Parser.__index:parse_call_string(start, expr)
   expr = self.visitor:visit_call(start, expr)
   local params = self:parse_call_params_string()
   expr = self.visitor:visit_call_end(expr, self:last_end_position(), params)
   return expr, true, true
end

function Parser.__index:parse_call_params_table()
   local list = self.visitor:visit_expression_list(self:start_position())
   local param = self:parse_table()
   list = self.visitor:visit_expression_list_expression(list, param)
   local params = self.visitor:visit_expression_list_end(list, self:last_end_position())
   return params
end

function Parser.__index:parse_call_table(start, expr)
   expr = self.visitor:visit_call(start, expr)
   local params = self:parse_call_params_table()
   expr = self.visitor:visit_call_end(expr, self:last_end_position(), params)
   return expr, true, true
end

function Parser.__index:parse_call_params()
   self:next_non_space_token()
   local params
   if self:is_token(")") then
      local pos = self:start_position()
      local list = self.visitor:visit_expression_list(pos)
      params = self.visitor:visit_expression_list_end(list, pos)
   else
      params = self:parse_expression_list()
   end
   self:expect_token(")")
   return params
end

function Parser.__index:parse_call(start, expr)
   expr = self.visitor:visit_call(start, expr)
   local params = self:parse_call_params()
   expr = self.visitor:visit_call_end(expr, self:last_end_position(), params)
   return expr, true, true
end

function Parser.__index:parse_method(start, expr)
   expr = self.visitor:visit_method_call(start, expr)
   self:next_non_space_token()
   local name = self:parse_identifier_string()
   expr = self.visitor:visit_method_call_member(expr, name)
   local params
   if self:is_token("(") then
      params = self:parse_call_params()
   elseif self:is_token("string") then
      params = self:parse_call_params_string()
   elseif self:is_token("{") then
      params = self:parse_call_params_table()
   else
      self:expect_token("(")
      local pos = self:last_end_position()
      local list = self.visitor:visit_expression_list(pos)
      params = self.visitor:visit_expression_list_end(list, pos)
   end
   expr = self.visitor:visit_method_call_end(expr, self:last_end_position(), params)
   return expr, true, true
end

function Parser.__index:parse_rexpression(start, expr, priority, allow_as_statement)
   while true do
      local handler = self.operator_handler[self.token]
      local again
      if not handler then return expr, allow_as_statement end
      expr, again, allow_as_statement = handler(self, start, expr, priority, allow_as_statement)
      if not again then return expr, allow_as_statement end
   end
end

function Parser.__index:parse_expression(priority)
   priority = priority or 0
   local start = self:start_position()
   local left, allow_as_statement = self:parse_lexpression(priority)
   return self:parse_rexpression(start, left, priority, allow_as_statement)
end

function Parser.__index:parse_expression_list()
   local list = self.visitor:visit_expression_list(self:start_position())
   local expr = self:parse_expression()
   list = self.visitor:visit_expression_list_expression(list, expr)
   while self:is_token(",") do
      self:next_non_space_token()
      expr = self:parse_expression()
      list = self.visitor:visit_expression_list_expression(list, expr)
   end
   return (self.visitor:visit_expression_list_end(list, self:last_end_position()))
end

function Parser.__index:parse_expression_statement_with_left(statement, left, allow_as_statement)
   local start, expr = self:start_position()
   expr, allow_as_statement = self:parse_rexpression(start, left, 0, allow_as_statement)
   if self:is_token(",") or self:is_token("=") then
      return self:parse_assignment(statement.start_position, expr)
   end
   if not allow_as_statement then
      self:error("Expression not acceptable as Statement")
   end
   statement = self.visitor:visit_expression_statement_end(statement, self:last_end_position(), expr)
   return statement
end

function Parser.__index:parse_expression_statement()
   local start = self:start_position()
   local statement = self.visitor:visit_expression_statement(start)
   local left, allow_as_statement = self:parse_lexpression(0)
   return self:parse_expression_statement_with_left(statement, left, allow_as_statement)
end

function Parser.__index:parse_empty_statement()
   local start = self:start_position()
   self:next_non_space_token()
   local statement = self.visitor:visit_empty_statement(start, self:last_end_position())
   return statement
end

function Parser.__index:parse_label()
   local start = self:start_position()
   self:next_non_space_token()
   local name = self:parse_identifier()
   self:expect_token("::")
   local label = self.visitor:visit_label(start, self:last_end_position(), name)
   return label
end

function Parser.__index:parse_declaration(allow_attributes)
   local start = self:start_position()
   local identifier = self:parse_identifier()
   local declaration = self.visitor:visit_declaration(start, identifier)
   if allow_attributes and self:is_token("<") then
      self:next_non_space_token()
      local name = self:parse_identifier()
      self:expect_token(">")
      declaration = self.visitor:visit_declaration_attribute(declaration, name)
   end
   declaration = self.visitor:visit_declaration_end(declaration, self:last_end_position())
   return declaration
end

function Parser.__index:parse_function(start, is_method)
   local func = self.visitor:visit_function(start, is_method)
   self:expect_token("(")
   if not self:is_token(")") then
      while true do
         if self:is_token("...") then
            self:next_non_space_token()
            func = self.visitor:visit_function_vararg(func)
            break
         end
         local var = self:parse_declaration(false)
         func = self.visitor:visit_function_parameter(func, var)
         if not self:is_token(",") then break end
         self:next_non_space_token()
      end
   end
   self:expect_token(")")
   local block = self:parse_statements(FunctionBlockContext)
   self:expect_keyword("end")
   func = self.visitor:visit_function_body(func, self:last_end_position(), block)
   return func
end

function Parser.__index:parse_function_expression()
   local start = self:start_position()
   self:next_non_space_token()
   return self:parse_function(start, false)
end

function Parser.__index:parse_function_statement()
   local start = self:start_position()
   self:next_non_space_token()
   local expr_start = self:start_position()
   local expr = self:parse_variable()
   while self:is_token(".") do
      expr = self:parse_field(expr_start, expr)
   end
   local is_method = self:is_token(":")
   if is_method then
      expr = self:parse_field(expr_start, expr)
   end
   local assignment = self.visitor:visit_assignment(start, expr)
   local list = self.visitor:visit_expression_list(start)
   local func = self:parse_function(start, is_method)
   local last = self:last_end_position()
   list = self.visitor:visit_expression_list_expression(list, func)
   list = self.visitor:visit_expression_list_end(list, last)
   func = self.visitor:visit_assignment_end(assignment, last, list)
   return func
end

function Parser.__index:parse_local_function(start)
   local decl = self.visitor:visit_local_function(start)
   start = self:start_position()
   self:next_non_space_token()
   local var = self:parse_declaration(false)
   decl = self.visitor:visit_local_function_declaration(decl, var)
   local func = self:parse_function(start, false)
   decl = self.visitor:visit_local_function_end(decl, self:last_end_position(), func)
   return decl
end

function Parser.__index:parse_local_default(start)
   local loc = self.visitor:visit_local(start)
   local decl = self:parse_declaration(true)
   loc = self.visitor:visit_local_declaration(loc, decl)
   while self:is_token(",") do
      self:next_non_space_token()
      decl = self:parse_declaration(true)
      loc = self.visitor:visit_local_declaration(loc, decl)
   end
   local list
   local last = self:last_end_position()
   if self:is_token("=") then
      self:next_non_space_token()
      list = self:parse_expression_list()
      last = self:last_end_position()
   else
      list = self.visitor:visit_expression_list(last)
      list = self.visitor:visit_expression_list_end(list, last)
   end
   return (self.visitor:visit_local_end(loc, last, list))
end

function Parser.__index:parse_local()
   local start = self:start_position()
   self:next_non_space_token()
   local handlers = self.local_handlers
   local handler = handlers[self.token] or self.parse_local_default
   local decl = handler(self, start)
   return decl
end

function Parser.__index:parse_goto()
   local start = self:start_position()
   self:next_non_space_token()
   if not self:is_non_reserved_identifier() and not self.reserved_identifiers["goto"] then
      -- goto but without identifier and goto is not a keyword
      -- try to parse it as an expression
      local statement = self.visitor:visit_expression_statement(start)
      local ident = self.visitor:visit_identifier(start, self:last_end_position(), "goto")
      local left = self.visitor:visit_variable(start, self:last_end_position(), ident)
      return self:parse_expression_statement_with_left(statement, left, false)
   end
   local ident = self:parse_identifier()
   local statement = self.visitor:visit_goto(start, self:last_end_position(), ident)
   return statement
end

function Parser.__index:parse_for_num(start, decl)
   local loop = self.visitor:visit_for_num(start, decl)
   self:next_non_space_token()
   start = self:parse_expression()
   loop = self.visitor:visit_for_num_start(loop, start)
   self:expect_token(",")
   local limit = self:parse_expression()
   loop = self.visitor:visit_for_num_limit(loop, limit)
   local step
   if self:is_token(",") then
      self:next_non_space_token()
      step = self:parse_expression()
   else
      local loc = self:last_end_position()
      step = self.visitor:visit_number(loc, loc, "1")
   end
   loop = self.visitor:visit_for_num_step(loop, step)
   self:expect_keyword("do")
   local statements = self:parse_statements(ForBlockContext)
   self:expect_keyword("end")
   return (self.visitor:visit_for_num_end(loop, self:last_end_position(), statements))
end

function Parser.__index:parse_for_in(start, decl)
   print("X")
   local loop = self.visitor:visit_for_in(start, decl)
   print(">")
   while self:is_token(",") do
      self:next_non_space_token()
      decl = self:parse_declaration(false)
      loop = self.visitor:visit_for_in_var(loop, decl)
   end
   self:expect_keyword("in")
   local list = self:parse_expression_list()
   loop = self.visitor:visit_for_in_init(loop, list)
   self:expect_keyword("do")
   local statements = self:parse_statements(ForBlockContext)
   self:expect_keyword("end")
   return (self.visitor:visit_for_in_end(loop, self:last_end_position(), statements))
end

function Parser.__index:parse_for()
   local start = self:start_position()
   self:next_non_space_token()
   local decl = self:parse_declaration(false)
   if self:is_token("=") then
      return self:parse_for_num(start, decl)
   end
   return self:parse_for_in(start, decl)
end

function Parser.__index:parse_if()
   local statement = self.visitor:visit_if(self:start_position())
   self:next_non_space_token()
   local pred = self:parse_expression()
   statement = self.visitor:visit_if_pred(statement, pred)
   self:expect_keyword("then")
   local true_branch = self:parse_statements(IfBlockContext)
   statement = self.visitor:visit_if_true(statement, true_branch)
   local else_branch
   if self:is_identifier_value("elseif") then
      else_branch = self.visitor:visit_statements(self:start_position())
      local s = self:parse_if()
      else_branch = self.visitor:visit_statements_statement(else_branch, s)
      else_branch = self.visitor:visit_statements_end(else_branch, self:last_end_position())
   elseif self:is_identifier_value("else") then
      self:next_non_space_token()
      else_branch = self:parse_statements(ElseBlockContext)
      self:expect_keyword("end")
   else
      self:expect_keyword("end")
      else_branch = self.visitor:visit_statements(self:last_end_position())
      else_branch = self.visitor:visit_statements_end(else_branch, self:last_end_position())
   end
   statement = self.visitor:visit_if_end(statement, self:last_end_position(), else_branch)
   return statement
end

function Parser.__index:parse_else()
   if self.block_context:ends(self) then return nil end
   self:error("Not in an if block")
   local start = self:start_position()
   local statement = self.visitor:visit_if(self:start_position())
   local t = self.visitor:visit_true(start, start)
   statement = self.visitor:visit_if_cond(statement, t)
   local true_branch = self.visitor:visit_statements(start)
   true_branch = self.visitor:visit_statements_end(true_branch, start)
   statement = self.visitor:visit_if_true(statement, true_branch)
   self:next_non_space_token()
   local else_branch = self:parse_statements(ElseBlockContext)
   self:expect_keyword("end")
   statement = self.visitor:visit_if_end(statement, self:last_end_position(), else_branch)
   return statement
end

function Parser.__index:parse_elseif()
   if self.block_context:ends(self) then return nil end
   self:error("Not in an if block")
   local start = self:start_position()
   local statement = self.visitor:visit_if(self:start_position())
   local t = self.visitor:visit_true(start, start)
   statement = self.visitor:visit_if_cond(statement, t)
   local true_branch = self.visitor:visit_statements(start)
   true_branch = self.visitor:visit_statements_end(true_branch, start)
   statement = self.visitor:visit_if_true(statement, true_branch)
   local else_branch = self:parse_if()
   statement = self.visitor:visit_if_end(statement, self:last_end_position(), else_branch)
   return statement
end

function Parser.__index:parse_do()
   local block = self.visitor:visit_block(self:start_position())
   self:next_non_space_token()
   local statements = self:parse_statements(DoBlockContext)
   self:expect_keyword("end")
   block = self.visitor:visit_block_end(block, self:last_end_position(), statements)
   return block
end

function Parser.__index:parse_while()
   local loop = self.visitor:visit_while(self:start_position())
   self:next_non_space_token()
   local expr = self:parse_expression()
   loop = self.visitor:visit_while_pred(loop, expr)
   self:expect_keyword("do")
   local statements = self:parse_statements(WhileBlockContext)
   self:expect_keyword("end")
   loop = self.visitor:visit_while_end(loop, self:last_end_position(), statements)
   return loop
end

function Parser.__index:parse_repeat()
   local loop = self.visitor:visit_repeat(self:start_position())
   self:next_non_space_token()
   local statements = self:parse_statements(RepeatBlockContext)
   loop = self.visitor:visit_repeat_body(loop, statements)
   self:expect_keyword("until")
   local expr = self:parse_expression()
   loop = self.visitor:visit_repeat_end(loop, self:last_end_position(), expr)
   return loop
end

function Parser.__index:parse_until()
   if self.block_context:ends(self) then return nil end
   self:error("Not in a repeat .. until block")
   local start = self:start_position()
   local loop = self.visitor:visit_repeat(start)
   local statements = self.visitor:visit_statements(start)
   statements = self.visitor:visit_statements_end(statements, start)
   loop = self.visitor:visit_repeat_body(loop, statements)
   self:next_non_space_token()
   local expr = self:parse_expression()
   loop = self.visitor:visit_repeat_end(loop, self:last_end_position(), expr)
   return loop
end

function Parser.__index:parse_end()
   if self.block_context:ends(self) then return nil end
   self:error("Block should not be terminated by end")
   local start = self:start_position()
   self:next_non_space_token()
   return (self.visitor:visit_empty_statement(start, self:last_end_position()))
end

function Parser.__index:parse_statement(ctx)
   local handlers = self.statement_handlers
   local handler = handlers[self.token] or self.parse_expression_statement
   return handler(self, ctx)
end

function Parser.__index:parse_statements(block_context)
   local last_block_context = self.block_context
   self.block_context = block_context
   local statements = self.visitor:visit_statements(self:start_position())
   local statement = self:parse_statement()
   while statement do
      statements = self.visitor:visit_statements_statement(statements, statement)
      statement = self:parse_statement()
   end
   statements = self.visitor:visit_statements_end(statements, self:last_end_position())
   self.block_context = last_block_context
   return statements
end

function Parser.__index:parse_chunk()
   self:next_non_space_token()
   local block = self:parse_statements(ChunkBlockContext)
   self:expect_token("eof")
   return block
end

return Parser
