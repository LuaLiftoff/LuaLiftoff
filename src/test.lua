
-- luacheck: globals print

local Lexer = require"lualiftoff.parser.lexer"
local Parser = require"lualiftoff.parser.parser"
local AstBuilder = require"lualiftoff.parser.ast-builder"
local inspect = require"lualiftoff.util.inspect"

local parser = Parser(Lexer("local function x(...) return ... end"), AstBuilder())
local out = parser:parse_chunk()

print(inspect.inspect(out))
