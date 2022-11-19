-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Lexer = require "lualiftoff.parser.lexer"

local function with_lexer(input, func)
   return function()
      local lexer = Lexer(input)
      func(lexer, input)
      assert.same("eof", lexer:next_token())
      assert.same(#input + 1, lexer.start)

      local index = 0
      lexer = Lexer(function()
         index = index + 1
         return string.sub(input, index, index)
      end)
      func(lexer, input)
      assert.same("eof", lexer:next_token())
      assert.same(#input + 1, lexer.start)

      index = -1
      lexer = Lexer(function()
         index = index + 2
         return string.sub(input, index, index + 1)
      end)
      func(lexer, input)
      assert.same("eof", lexer:next_token())
      assert.same(#input + 1, lexer.start)
   end
end

describe("Lexer", function()
   it("eof", with_lexer("", function(lexer)
      assert.same("eof", lexer:next_token())
      assert.same(1, lexer.start)
   end))
   it("singe identifier", with_lexer("abc def0123_", function(lexer)
      assert.same("identifier", lexer:next_token())
      assert.same("abc", lexer.value)
      assert.same("space", lexer:next_token())
      assert.same("identifier", lexer:next_token())
      assert.same("def0123_", lexer.value)
   end))
   it("singe number", with_lexer("0 1 2 3 4 5 6 7 8 9 0x1234", function(lexer)
      for i = 0, 9 do
         assert.same("number", lexer:next_token())
         assert.same(tostring(i), lexer.value)
         assert.same("space", lexer:next_token())
      end
      assert.same("number", lexer:next_token())
      assert.same("0x1234", lexer.value)
   end))
   it("comment", with_lexer("--abc\n--[=def", function(lexer)
      assert.same("comment", lexer:next_token())
      assert.same("abc", lexer.value)
      assert.same("space", lexer:next_token())
      assert.same("comment", lexer:next_token())
      assert.same("[=def", lexer.value)
   end))
   it("long comment", with_lexer("--[[abc\ndef]] --[=[ghj]==]]]=] --[==[x]=]==]", function(lexer)
      assert.same("comment", lexer:next_token())
      assert.same("abc\ndef", lexer.value)
      assert.same(2, lexer.line)
      assert.same("space", lexer:next_token())
      assert.same("comment", lexer:next_token())
      assert.same("ghj]==]]", lexer.value)
      assert.same("space", lexer:next_token())
      assert.same("comment", lexer:next_token())
      assert.same("x]=", lexer.value)
   end))
   it("string", with_lexer("\"a\"'b''\"''a\\z \n b\\\nc\\x41\\u{41}\\65A\\n\\\"'", function(lexer)
      assert.same("string", lexer:next_token())
      assert.same("a", lexer.value)
      assert.same("string", lexer:next_token())
      assert.same("b", lexer.value)
      assert.same("string", lexer:next_token())
      assert.same("\"", lexer.value)
      assert.same("string", lexer:next_token())
      assert.same("ab\ncAAAA\n\"", lexer.value)
      assert.same(3, lexer.line)
   end))
   it("long string", with_lexer("[[str]][[\nabc\nd\r\ne\\]]", function(lexer)
      assert.same("string", lexer:next_token())
      assert.same("str", lexer.value)
      assert.same("string", lexer:next_token())
      assert.same("abc\nd\ne\\", lexer.value)
      assert.same(4, lexer.line)
   end))
   it("tokens", with_lexer("> >> >= . .. ... ~= == = / // :: : < << <= [ ] ( ) { } ", function(lexer, input)
      for k in input:gmatch("%S+") do
         assert.same(k, lexer:next_token())
         assert.same("space", lexer:next_token())
      end
   end))
   it("tokens splitting", with_lexer(">>>=....++", function(lexer)
      assert.same(">>", lexer:next_token())
      assert.same(">=", lexer:next_token())
      assert.same("...", lexer:next_token())
      assert.same(".", lexer:next_token())
      assert.same("+", lexer:next_token())
      assert.same("+", lexer:next_token())
   end))
end)
