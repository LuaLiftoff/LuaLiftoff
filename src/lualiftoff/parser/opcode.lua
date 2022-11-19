-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local error = require"lualiftoff.lua.error"

local ACC_D = 0
local ACC_R = 1
local ACC_W = 2
local ACC_RW = 3
local ACC_V = 4

local EXT_LR = 1
local EXT_LX = 2
local EXT_LU = 3
local EXT_LC = 4
local EXT_LI = 5
local EXT_SR = 6
local EXT_SX = 7
local EXT_SU = 8
local EXT_J = 9
local EXT_LSR = 10
local EXT_SRL = 11
local EXT_LRL = 12


local next = 0

local opcodes = {}

local function nextOpcode(name, acc_use, reg_use, second, third)
   if next >= 256 then error.error("Too many opcodes") end
   local opcode = next
   next = next + 1
   opcodes[name] = opcode
   opcodes[opcode] = {name, acc_use, reg_use, second, third}
   return opcode
end

local function binaryOpcode(name)
   nextOpcode(name .. "_AR", ACC_RW, EXT_LR)
   nextOpcode(name .. "_RA", ACC_RW, EXT_LR)
   nextOpcode(name .. "_AU", ACC_RW, EXT_LX)
   nextOpcode(name .. "_UA", ACC_RW, EXT_LX)
   nextOpcode(name .. "_AC", ACC_RW, EXT_LC)
   nextOpcode(name .. "_CA", ACC_RW, EXT_LC)
   nextOpcode(name .. "_AI", ACC_RW, EXT_LI)
   nextOpcode(name .. "_IA", ACC_RW, EXT_LI)
end

local function binaryTestOpcode(name)
   nextOpcode(name .. "_AR", ACC_R, EXT_LR, EXT_J, EXT_J)
   nextOpcode(name .. "_RA", ACC_R, EXT_LR, EXT_J, EXT_J)
   nextOpcode(name .. "_AU", ACC_R, EXT_LX, EXT_J, EXT_J)
   nextOpcode(name .. "_UA", ACC_R, EXT_LX, EXT_J, EXT_J)
   nextOpcode(name .. "_AC", ACC_R, EXT_LC, EXT_J, EXT_J)
   nextOpcode(name .. "_CA", ACC_R, EXT_LC, EXT_J, EXT_J)
   nextOpcode(name .. "_AI", ACC_R, EXT_LI, EXT_J, EXT_J)
   nextOpcode(name .. "_IA", ACC_R, EXT_LI, EXT_J, EXT_J)
end

binaryOpcode("ADD")
binaryOpcode("SUB")
binaryOpcode("MUL")
binaryOpcode("DIV")
binaryOpcode("IDIV")
binaryOpcode("MOD")
binaryOpcode("POW")
binaryOpcode("OR")
binaryOpcode("XOR")
binaryOpcode("AND")
binaryOpcode("SHL")
binaryOpcode("SHR")

binaryOpcode("CONCAT")

nextOpcode("NEG", ACC_RW)
nextOpcode("NOT", ACC_RW)
nextOpcode("LEN", ACC_RW)
nextOpcode("NOT", ACC_RW)

binaryTestOpcode("EQ")
binaryTestOpcode("NEQ")
binaryTestOpcode("LT")
binaryTestOpcode("NLT")
binaryTestOpcode("LE")
binaryTestOpcode("NLE")
nextOpcode("TEST", ACC_R, EXT_J)
nextOpcode("NTEST", ACC_R, EXT_J)
nextOpcode("TEST_L", ACC_R, EXT_J, EXT_J, EXT_J)
nextOpcode("NTEST_L", ACC_R, EXT_J, EXT_J, EXT_J)

nextOpcode("GET_FIELD", ACC_RW, EXT_LR)
nextOpcode("GET_FIELD_RU", ACC_RW, EXT_LX)
nextOpcode("GET_FIELD_U", ACC_RW, EXT_LU)
nextOpcode("GET_FIELD_S", ACC_RW, EXT_LC)
nextOpcode("GET_FIELD_I", ACC_RW, EXT_LI)

nextOpcode("SET_FIELD", ACC_R, EXT_LR, EXT_LR)
nextOpcode("SET_FIELD_RU", ACC_R, EXT_LX, EXT_LR)
nextOpcode("SET_FIELD_U", ACC_R, EXT_LU, EXT_LR)
nextOpcode("SET_FIELD__RU", ACC_R, EXT_LR, EXT_LX)
nextOpcode("SET_FIELD_RU_RU", ACC_R, EXT_LX, EXT_LX)
nextOpcode("SET_FIELD_U_RU", ACC_R, EXT_LU, EXT_LX)
nextOpcode("SET_FIELD__S", ACC_R, EXT_LR, EXT_LC)
nextOpcode("SET_FIELD_RU_S", ACC_R, EXT_LX, EXT_LC)
nextOpcode("SET_FIELD_U_S", ACC_R, EXT_LU, EXT_LC)
nextOpcode("SET_FIELD__I", ACC_R, EXT_LR, EXT_LI, EXT_LI)
nextOpcode("SET_FIELD_RU_I", ACC_R, EXT_LX, EXT_LI, EXT_LI)
nextOpcode("SET_FIELD_U_I", ACC_R, EXT_LU, EXT_LI, EXT_LI)

nextOpcode("GET", ACC_W, EXT_LR)
nextOpcode("GET_REG_UPVAL", ACC_W, EXT_LX)
nextOpcode("GET_UPVAL", ACC_W, EXT_LU)
nextOpcode("GET_INT", ACC_W, EXT_LI)
nextOpcode("GET_CONST", ACC_W, EXT_LC)
nextOpcode("GET_PRIM", ACC_W, EXT_LI)

nextOpcode("SET", ACC_R, EXT_SR)
nextOpcode("SET_REG_UPVAL", ACC_R, EXT_SX)
nextOpcode("SET_UPVAL", ACC_R, EXT_SU)

nextOpcode("VARARGS", ACC_D, EXT_SR, EXT_SRL)
nextOpcode("VARARGS_V", ACC_W | ACC_V, EXT_SR)

nextOpcode("CALL_CC", ACC_D, EXT_LSR, EXT_LRL, EXT_SRL)
nextOpcode("CALL_CV", ACC_W | ACC_V, EXT_LSR, EXT_LRL)
nextOpcode("CALL_VV", ACC_RW | ACC_V, EXT_LSR)
nextOpcode("CALL_VC", ACC_R | ACC_V, EXT_LSR, EXT_SRL)

nextOpcode("TAIL_CALL_C", ACC_D, EXT_LR, EXT_LRL)
nextOpcode("TAIL_CALL_V", ACC_R | ACC_V, EXT_LR)

nextOpcode("RETURN_C", ACC_D, EXT_LR)
nextOpcode("RETURN_V", ACC_R | ACC_V, EXT_LR)
nextOpcode("RETURN0", ACC_D)
nextOpcode("RETURN1", ACC_R)
nextOpcode("RETURN2", ACC_R, EXT_LR)
nextOpcode("RETURN2_UP", ACC_R, EXT_LX)

nextOpcode("JUMP", ACC_D, EXT_J)
nextOpcode("JUMP_L", ACC_D, EXT_J, EXT_J, EXT_J)

nextOpcode("NEW_CLOSURE", ACC_W, EXT_LC)
nextOpcode("NEW_TABLE", ACC_W, EXT_LI, EXT_LI, EXT_LI)
nextOpcode("DUP_TABLE", ACC_W, EXT_LC)
nextOpcode("NEW_UPVAL", ACC_R, EXT_SR)

nextOpcode("FOR_PREP", ACC_D, EXT_SR, EXT_J, EXT_J)
nextOpcode("FOR_PREP1", ACC_D, EXT_SR, EXT_J, EXT_J)
nextOpcode("FOR_LOOP", ACC_D, EXT_SR, EXT_J, EXT_J)

nextOpcode("TFOR_PREP", ACC_D, EXT_SR, EXT_J, EXT_J)
nextOpcode("TFOR_LOOP", ACC_D, EXT_LSR, EXT_SRL, EXT_J)

nextOpcode("WIDE", ACC_D, EXT_LI)

return opcodes
