-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require "lualiftoff.util.class"
local string = require "lualiftoff.lua.string"
local table = require "lualiftoff.lua.table"
local assert = require "lualiftoff.lua.assert"
local error = require "lualiftoff.lua.error"

local EOF = -1

local NL = string.byte "\n"
local CR = string.byte "\r"

local Lexer = Class "Lexer"

local char_tags = {}
for i = -1, 255 do
   char_tags[i] = {
      is_identifier = false,
      is_space = false
   }
end

local function gen_nil()
   return ""
end

local function make_call_method(name)
   return function(obj, ...)
      return obj[name](obj, ...)
   end
end

local function make_replace_escape(with)
   return function(lexer)
      lexer:next_char()
      return with
   end
end

local function newline_escape(lexer, c)
   lexer:skip_newline(c)
   return "\n"
end

local default_escape_handlers = {
   [string.byte "x"] = make_call_method("handle_hex_escape"),
   [string.byte "z"] = make_call_method("handle_zap_sapce_escape"),
   [string.byte "u"] = make_call_method("handle_unicode_escape"),
   [string.byte "a"] = make_replace_escape("\a"),
   [string.byte "b"] = make_replace_escape("\b"),
   [string.byte "f"] = make_replace_escape("\f"),
   [string.byte "n"] = make_replace_escape("\n"),
   [string.byte "r"] = make_replace_escape("\r"),
   [string.byte "t"] = make_replace_escape("\t"),
   [string.byte "v"] = make_replace_escape("\v"),
   [string.byte "\\"] = make_replace_escape("\\"),
   [string.byte "\""] = make_replace_escape("\""),
   [string.byte "'"] = make_replace_escape("'"),
   [string.byte "\n"] = newline_escape,
   [string.byte "\r"] = newline_escape,
}

local handle_digit_escape = make_call_method("handle_digit_escape")
for i = 0, 9 do
   default_escape_handlers[string.byte(string.to_string(i))] = handle_digit_escape
end

local handle_long_string = make_call_method("handle_long_string")

local handle_default = make_call_method("handle_default")

local function make_handle_token(what)
   return function(lexer, _c, len)
      lexer:next_char(len)
      return what
   end
end

local handle_string = make_call_method("handle_string")

local default_handlers = {
   [string.byte "'"] = handle_string,
   [string.byte "\""] = handle_string,
   [string.byte "-"] = {
      [string.byte "-"] = make_call_method("handle_comment"),
      handler = make_handle_token("-")
   },
   [string.byte "["] = {
      [string.byte "["] = handle_long_string,
      [string.byte "="] = handle_long_string,
      handler = make_handle_token("[")
   },
   [string.byte "<"] = {
      [string.byte "<"] = make_handle_token("<<"),
      [string.byte "="] = make_handle_token("<="),
      handler = make_handle_token("<")
   },
   [string.byte ">"] = {
      [string.byte ">"] = make_handle_token(">>"),
      [string.byte "="] = make_handle_token(">="),
      handler = make_handle_token(">")
   },
   [string.byte "="] = {
      [string.byte "="] = make_handle_token("=="),
      handler = make_handle_token("=")
   },
   [string.byte "~"] = {
      [string.byte "="] = make_handle_token("~="),
      handler = make_handle_token("~")
   },
   [string.byte "."] = {
      [string.byte "."] = {
         [string.byte "."] = make_handle_token("..."),
         handler = make_handle_token("..")
      },
      handler = make_handle_token(".")
   },
   [string.byte ":"] = {
      [string.byte ":"] = make_handle_token("::"),
      handler = make_handle_token(":")
   },
   [string.byte "/"] = {
      [string.byte "/"] = make_handle_token("//"),
      handler = make_handle_token("/")
   },
   handler = handle_default
}

local handle_spaces = make_call_method("handle_spaces")
local spaces = " \t\r\n\v\f"
for i = 1, #spaces do
   default_handlers[string.byte(spaces, i)] = handle_spaces
   char_tags[string.byte(spaces, i)].is_space = true
end

local handle_number = make_call_method("handle_number")
for i = 0, 9 do
   local b = string.byte(string.to_string(i))
   default_handlers[b] = handle_number
   char_tags[b].is_identifier = true
end

local handle_identifier = make_call_method("handle_identifier")
local identifiers = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
for i = 1, #identifiers do
   local b = string.byte(identifiers, i)
   default_handlers[b] = handle_identifier
   char_tags[b].is_identifier = true
end

function Lexer.__index:init(gen)
   if Class.type(gen) == "string" then
      self.gen = gen_nil
      self.buffer = gen
   else
      self.gen = gen
      self.buffer = ""
   end
   self.next_buffers = {}
   self.line = 1
   self.line_position = 1
   self.buffer_position = 0
   self.offset = 1
   self.handlers = default_handlers
   self.escape_handlers = default_escape_handlers
   self.start = 1
   self.start_line = 1
   self.start_line_position = 1
   self.value = false
   return self
end

function Lexer.__index:error(message)
   error.error(message)
end

function Lexer.__index:next_buffer()
   local next_buffers = self.next_buffers
   local num = #next_buffers
   if num > 0 then
      local buffer = next_buffers[num]
      next_buffers[num] = nil
      return buffer
   end
   local buffer = self.gen()
   assert(Class.type(buffer) == "string")
   if buffer == "" then
      self.gen = gen_nil
   end
   return buffer
end

function Lexer.__index:next_char(amount)
   amount = amount or 1
   local offset = self.offset + amount
   local buffer = self.buffer
   while #buffer < offset do
      offset = offset - #buffer
      self.buffer_position = self.buffer_position + #buffer
      buffer = self:next_buffer()
      if buffer == "" then
         self.buffer = buffer
         self.offset = 1
         return EOF
      end
   end
   self.buffer = buffer
   self.offset = offset
   return string.byte(buffer, offset)
end

function Lexer.__index:read_until(predicate)
   local offset = self.offset
   local buffer = self.buffer
   while #buffer < offset do
      offset = offset - #buffer
      self.buffer_position = self.buffer_position + #buffer
      buffer = self:next_buffer()
      if buffer == "" then
         self.buffer = buffer
         self.offset = 1
         return "", EOF
      end
   end
   local start_offset = offset
   local c = string.byte(buffer, offset)
   while not predicate(c) do
      offset = offset + 1
      if #buffer < offset then
         local parts = {string.sub(buffer, start_offset)}
         self.buffer_position = self.buffer_position + #buffer
         buffer = self:next_buffer()
         if buffer == "" then
            self.buffer = buffer
            self.offset = 1
            return parts[1], EOF
         end
         offset = 1
         c = string.byte(buffer, offset)
         while not predicate(c) do
            offset = offset + 1
            if #buffer < offset then
               parts[#parts + 1] = buffer
               self.buffer_position = self.buffer_position + #buffer
               buffer = self:next_buffer()
               if buffer == "" then
                  self.buffer = buffer
                  self.offset = 1
                  return table.concat(parts), EOF
               end
               offset = 1
            end
            c = string.byte(buffer, offset)
         end
         parts[#parts + 1] = string.sub(buffer, 1, offset - 1)
         self.buffer = buffer
         self.offset = offset
         return table.concat(parts), c
      end
      c = string.byte(buffer, offset)
   end
   self.offset = offset
   return string.sub(buffer, start_offset, offset - 1), c
end

local function is_newline(c)
   return c == NL or c == CR
end

function Lexer.__index:skip_newline(c)
   local next = self:next_char()
   if next ~= c and is_newline(next) then
      next = self:next_char()
   end
   self.line = self.line + 1
   self.line_position = self.buffer_position + self.offset
   return next
end

function Lexer.__index:skip_spaces(c)
   while char_tags[c].is_space do
      if is_newline(c) then
         c = self:skip_newline(c)
      else
         c = self:next_char()
      end
   end
   return c
end

function Lexer.__index:handle_spaces(c)
   self:skip_spaces(c)
   return "space"
end

local function is_not_identifier(c)
   return not char_tags[c].is_identifier
end

local function is_special_long(c)
   return c == string.byte "]" or is_newline(c)
end

function Lexer.__index:handle_identifier()
   self.value = self:read_until(is_not_identifier)
   return "identifier"
end

function Lexer.__index:handle_number()
   self.value = self:read_until(is_not_identifier)
   return "number"
end

function Lexer.__index:read_long_string(c, sep, token)
   if is_newline(c) then
      self:skip_newline(c)
   end
   local parts = {}
   local part
   while true do
      part, c = self:read_until(is_special_long)
      parts[#parts + 1] = part
      if c == string.byte "]" then
         local dep = 0
         c = self:next_char()
         while c == string.byte "=" do
            dep = dep + 1
            c = self:next_char()
         end
         if c == string.byte "]" and dep == sep then
            self.value = table.concat(parts)
            self:next_char()
            return token
         end
         parts[#parts + 1] = "]"
         parts[#parts + 1] = string.rep("=", dep)
      elseif is_newline(c) then
         self:skip_newline(c)
         parts[#parts + 1] = "\n"
      else
         self:error("Invalid long " .. token)
         self.value = table.concat(parts)
         return token
      end
   end
end

function Lexer.__index:handle_comment(_c, prefix_len)
   local c = self:next_char(prefix_len)
   if c ~= string.byte "[" then
      self.value = self:read_until(is_newline)
      return "comment"
   end
   c = self:next_char()
   local dep = 0
   while c == string.byte "=" do
      dep = dep + 1
      c = self:next_char()
   end
   if c ~= string.byte "[" then
      self.value = "[" .. string.rep("=", dep) .. self:read_until(is_newline)
      return "comment"
   end
   c = self:next_char()
   return self:read_long_string(c, dep, "comment")
end

function Lexer.__index:handle_long_string(c)
   assert(c == string.byte "[")
   c = self:next_char()
   local dep = 0
   while c == string.byte "=" do
      dep = dep + 1
      c = self:next_char()
   end
   if c == string.byte "[" then
      c = self:next_char()
   else
      self:error("Invalid long string")
   end
   return self:read_long_string(c, dep, "string")
end

local function is_string_special(c)
   return c == string.byte "'" or c == string.byte '"' or c == string.byte "\\" or is_newline(c)
end

local function hex_value(c)
   if c >= string.byte "0" and c <= string.byte "9" then
      return c - string.byte "0"
   elseif c >= string.byte "a" and c <= string.byte "z" then
      return c - string.byte "a" + 10
   elseif c >= string.byte "A" and c <= string.byte "Z" then
      return c - string.byte "A" + 10
   end
   return -1
end

function Lexer.__index:handle_hex_escape(start)
   local c = self:next_char()
   local h1 = hex_value(c)
   if h1 < 0 or h1 > 15 then
      self:error("Invalid hex escape")
      return "\\" .. string.char(start)
   end
   local h2 = hex_value(self:next_char())
   if h2 < 0 or h2 > 15 then
      self:error("Invalid hex escape")
      return "\\" .. string.char(start, c)
   end
   self:next_char()
   return string.char(h1 * 16 + h2)
end

function Lexer.__index:handle_zap_sapce_escape()
   self:skip_spaces(self:next_char())
   return ""
end

function Lexer.__index:handle_digit_escape(c)
   local v = c - string.byte "0"
   local n = self:next_char() - string.byte "0"
   if n >= 0 and n <= 9 then
      v = v * 10 + n
      n = self:next_char() - string.byte "0"
      if n >= 0 and n <= 9 then
         v = v * 10 + n
         if v > 255 then
            self:error("Invalid digit escape")
            v = v & 255
         end
         self:next_char()
      end
   end
   return string.char(v)
end

function Lexer.__index:handle_unicode_escape(start)
   local c = self:next_char()
   if c ~= string.byte "{" then
      self:error("Invalid unicode escape")
      return "\\" .. string.char(start)
   end
   c = self:next_char()
   local v = hex_value(c)
   if v < 0 or v > 15 then
      self:error("hexadecimal digit expected")
      return "\\" .. string.char(start) .. "{"
   end
   c = self:next_char()
   local hv = hex_value(c)
   while hv >= 0 and hv <= 15 do
      if v >= 0x8000000 then
         self:error("UTF-8 value too large")
         v = v % 0x8000000
      end
      v = v * 16 + hv
      c = self:next_char()
      hv = hex_value(c)
   end
   if c == string.byte "}" then
      self:next_char()
   else
      self:error("Invalid unicode escape")
   end
   if v < 0x80 then return string.char(v) end
   local space = 0x3f
   local str = ""
   repeat
      local cv = v % 0x40
      v = (v - cv) / 0x40
      str = string.char(0x80 + cv) .. str
      space = (space - 1) / 2
      assert(space > 0)
   until v <= space
   local prefix = 0xFE - space * 2
   return string.char(prefix + v) .. str
end

function Lexer.__index:handle_string(del)
   self:next_char()
   local part, c = self:read_until(is_string_special)
   if c == del then
      self.value = part
      self:next_char()
      return "string"
   end
   local parts = {part}
   while true do
      if c == string.byte "\\" then
         c = self:next_char()
         local handler = self.escape_handlers[c]
         if handler then
            parts[#parts + 1] = handler(self, c)
         else
            self:error("Invalid escape sequence")
            parts[#parts + 1] = "\\"
            parts[#parts + 1] = string.char(c)
         end
      elseif is_newline(c) or c == EOF then
         self:error("Unterminated string")
         self.value = table.concat(parts)
         return "string"
      else
         parts[#parts + 1] = string.char(c)
         self:next_char()
      end
      part, c = self:read_until(is_string_special)
      parts[#parts + 1] = part
      if c == del then
         self.value = table.concat(parts)
         self:next_char()
         return "string"
      end
   end
end

function Lexer.__index:handle_default(c)
   self:next_char()
   return string.char(c)
end

function Lexer.__index:next_token()
   local offset = self.offset
   local buffer = self.buffer
   self.value = nil
   self.start = self.buffer_position + offset
   self.start_line = self.line
   self.start_line_position = self.line_position
   while #buffer < offset do
      offset = offset - #buffer
      buffer = self:next_buffer()
      self.buffer = buffer
      self.offset = offset
      if buffer == "" then
         return "eof"
      end
   end
   local handlers = self.handlers
   local next_buffers
   local best_handler = handlers.handler
   local best_prefix_len = 0
   local c = string.byte(buffer, offset)
   local first_char = c
   local prefix_len = 1
   handlers = handlers[c]
   while handlers do
      if Class.type(handlers) == "function" then
         best_handler = handlers
         best_prefix_len = prefix_len
         break
      elseif handlers.handler then
         best_handler = handlers.handler
         best_prefix_len = prefix_len
      end
      offset = offset + 1
      prefix_len = prefix_len + 1
      if #buffer < offset then
         buffer = self:next_buffer()
         if buffer == "" then
            break
         end
         offset = 1
         if not next_buffers then
            next_buffers = {buffer}
         else
            next_buffers[#next_buffers + 1] = buffer
         end
      end
      c = string.byte(buffer, offset)
      handlers = handlers[c]
   end
   if next_buffers then
      local to = self.next_buffers
      for i = #next_buffers, 1, -1 do
         to[#to + 1] = next_buffers[i]
      end
   end
   return best_handler(self, first_char, best_prefix_len)
end

return Lexer
