
local function is_u32(x)
   return x >= 0 and x <= 0xFFFFFFFF and math.floor(x) == x
end

local function u32and(a, b)
   assert(is_u32(a) and is_u32(b))
   local res = 0
   local c = 1
   while a > 0 and b > 0 do
      local a_b, b_b = a % 2, b % 2
      if a_b + b_b == 2 then
         res = res + c
      end
      a, b, c = (a-a_b)/2, (b-b_b)/2, c*2
   end
   return res
end

local function u32or(a, b)
   assert(is_u32(a) and is_u32(b))
   local res = 0
   local c = 1
   while a > 0 and b > 0 do
      local a_b, b_b = a % 2, b % 2
      if a_b + b_b > 0 then
         res = res + c
      end
      a, b, c = (a-a_b)/2, (b-b_b)/2, c*2
   end
   return res + (a + b) * c
end

local function u32xor(a, b)
   assert(is_u32(a) and is_u32(b))
   local res = 0
   local c = 1
   while a > 0 and b > 0 do
      if a == b then return res end
      local a_b, b_b = a % 2, b % 2
      if a_b + b_b == 1 then
         res = res + c
      end
      a, b, c = (a-a_b)/2, (b-b_b)/2, c*2
   end
   return res + (a + b) * c
end

local function u32not(a)
   assert(is_u32(a))
   return (-1-a) % 0x100000000
end

local function u64mul(a_l, a_h, b_l, b_h)
   assert(is_u32(a_l) and is_u32(a_h) and is_u32(b_l) and is_u32(b_h))
   local aa_l, bb_l = a_l % 0x400000, b_l % 0x400000 -- 22 bit @ offset 0
   local aa_m, bb_m = a_h % 0x1000, b_h % 0x1000
   local aa_h, bb_h = (a_h - aa_m) / 0x1000, (b_h - bb_m) / 0x1000 -- 20 bit @ offset 44
   aa_m, bb_m = (a_l - aa_l) / 0x400000 + aa_m * 0x400, (b_l - bb_l) / 0x400000 + bb_m * 0x400 -- 22 bit @ offset 22
   local r_l = aa_l * bb_l -- 44 bit @ offset 0
   local r_m = aa_l * bb_m + aa_m * bb_l -- 45 bit @ offset 22
   local r_h = (aa_l + aa_m) * bb_h + aa_h * (bb_l + bb_m) -- 44 bit @ offset 44
   local k_m = r_m % 0x400
   local rr_ll = r_l + k_m * 0x400000
   local rr_l = rr_ll % 0x100000000
   local rr_h = (rr_ll - rr_l) / 0x100000000 + (r_m - k_m) / 0x400 + (r_h % 0x100000) * 0x1000
   return rr_l, rr_h % 0x100000000
end

local shifts = {}

do
   local s = 1
   for i = 0, 31 do
      shifts[i] = s
      s = s * 2
   end
end

local function u64shl(a_l, a_h, b)
   assert(b >= 0 and b < 64)
   if b == 0 then return a_l, a_h end
   if b < 32 then
      local s = shifts[b]
      a_l, a_h = a_l * s, (a_h * s) % 0x100000000
      local a_ll = a_l % 0x100000000
      return a_ll, a_h + (a_l - a_ll) / 0x100000000
   end
   if b == 32 then return 0, a_l end
   local s = shifts[b-32]
   return 0, (a_l * s) % 0x100000000
end

local function u64shr(a_l, a_h, b)
   assert(b >= 0 and b < 64)
   if b == 0 then return a_l, a_h end
   if b < 32 then
      local s = shifts[b]
      local r_l, r_h = a_l % s, a_h % s
      return ((a_l - r_l) + r_h * 0x100000000) / s, (a_h - r_h) / s
   end
   if b == 32 then return a_h, 0 end
   local s = shifts[b-32]
   local r = a_h % s
   return (a_h - r) / s, 0
end

local function u64add(a_l, a_h, b_l, b_h)
   local l_s = a_l + b_l
   local h_s = a_h + b_h
   local l_sr = l_s % 0x100000000
   return l_sr, (h_s + (l_s - l_sr) / 0x100000000) % 0x100000000
end

local function u64sub(a_l, a_h, b_l, b_h)
   local l_s = a_l - b_l
   local h_s = a_h - b_h
   if l_s < 0 then
      l_s, h_s = l_s + 0x100000000, h_s - 1
   end
   return l_s, h_s % 0x100000000
end

local function u64neg(a_l, a_h)
   a_h = -a_h
   if a_l == 0 then return 0, a_h % 0x100000000 end
   return 0x100000000 - a_l, a_h + 0xFFFFFFFF
end

local function u64div(a_l, a_h, b_l, b_h)
   if b_l + b_h == 0 then error("attempt to divide by zero") end
   if a_h == 0 then
      if b_h ~= 0 or a_l == 0 then return 0, 0, a_l, 0 end
      local rem = a_l % b_l
      a_l = (a_l - rem) / b_l
      return a_l, 0, rem, 0
   end
   local cnt = 0
   local r_l, r_h = 0, 0
   while b_h < 0x80000000 do
      local t_h = a_h - b_h
      if a_l < b_l then
         t_h = t_h - 1
      end
      if t_h < 0 then -- a < b
         if cnt == 0 then return 0, 0, a_l, a_h end
         cnt, b_l, b_h = cnt-1, u64shr(b_l, b_h, 1)
         break
      end
      cnt, b_l, b_h = cnt+1, u64shl(b_l, b_h, 1)
   end
   while true do
      local t_l, t_h = a_l - b_l, a_h - b_h
      if t_l < 0 then
         t_l, t_h = t_l + 0x100000000, t_h - 1
      end
      if t_h >= 0 then -- a >= b
         a_l, a_h = t_l, t_h
         if cnt >= 32 then
            r_h = r_h + shifts[cnt-32]
         else
            r_l = r_l + shifts[cnt]
         end
         if a_l + a_h == 0 then break end
      end
      if cnt == 0 then break end
      b_l, b_h = u64shr(b_l, b_h, 1)
      cnt = cnt - 1
   end
   return r_l, r_h, a_l, a_h
end

local function i64div(a_l, a_h, b_l, b_h)
   local a_n, b_n, r_l, r_h = false, false, nil, nil
   if a_h > 0x7FFFFFFF then
      a_n, a_l, a_h = true, u64neg(a_l, a_h)
   end
   if b_h > 0x7FFFFFFF then
      b_n, b_l, b_h = true, u64neg(b_l, b_h)
   end
   a_l, a_h, r_l, r_h = u64div(a_l, a_h, b_l, b_h)
   if a_n ~= b_n then
      a_l, a_h = u64neg(a_l, a_h)
      if r_l + r_h ~= 0 then
         a_l, a_h = u64sub(a_l, a_h, 1, 0)
         if b_n then
            r_l, r_h = u64sub(r_l, r_h, b_l, b_h)
         end
      end
   elseif b_n and r_l + r_h ~= 0 then
      r_l, r_h = u64sub(r_l, r_h, b_l, b_h)
   end
   return a_l, a_h, r_l, r_h
end

local int64 = {}
int64.__index = int64

local function is_int64(x)
   return getmetatable(x) == int64
end

local function to_int64(x)
   if is_int64(x) then return x[1], x[2] end
   if type(x) == "number" then
      local neg = false
      if x < 0 then neg, x = true, -x end
      local lo = x % 0x100000000
      local hi = (x - lo) / 0x100000000
      assert(is_u32(hi))
      if neg then
         lo, hi = u64neg(lo, hi)
      end
      return lo, hi
   end
   error("Invalid")
end

local function new_int64(lo, hi)
   assert(is_u32(lo) and is_u32(hi))
   return setmetatable({lo, hi}, int64)
end

function int64.new(hi, lo)
   if lo == nil then lo, hi = to_int64(hi) end
   if hi < 0 then lo, hi = u64neg(lo, -hi) end
   return new_int64(lo, hi)
end

setmetatable(int64, {
   __call = function(self, hi, lo)
      return self.new(hi, lo)
   end
})

int64.zero = new_int64(0, 0)
int64.one = new_int64(1, 0)
int64.negative_one = new_int64(0xFFFFFFFF, 0xFFFFFFFF)

function int64:to_number()
   if self[2] <= 0x7FFFFFFF then return self[2] * 0x100000000 + self[1] end
   local r_l, r_h = u64neg(self[1], self[2])
   return -(r_h * 0x100000000 + r_l)
end

function int64.__lt(a, b)
   if is_int64(a) then
      if is_int64(b) then
         local _, r_h = u64sub(a[1], a[2], b[1], b[2])
         return r_h > 0x7FFFFFFF
      end
      a = int64.to_number(a)
   elseif is_int64(b) then b = int64.to_number(b) end
   return a < b
end

function int64.__le(a, b)
   if is_int64(a) then
      if is_int64(b) then
         local r_l, r_h = u64sub(a[1], a[2], b[1], b[2])
         return r_h > 0x7FFFFFFF or (r_l + r_h == 0)
      end
      a = int64.to_number(a)
   elseif is_int64(b) then b = int64.to_number(b) end
   return a <= b
end

function int64.__eq(a, b)
   return a[1] == b[1] and a[2] == b[2]
end

function int64.__unm(a)
   return new_int64(u64neg(a[1], a[2]))
end

function int64.__add(a, b)
   if is_int64(a) then
      if is_int64(b) then return new_int64(u64add(a[1], a[2], b[1], b[2])) end
      a = int64.to_number(a)
   elseif is_int64(b) then b = int64.to_number(b) end
   return a + b
end

function int64.__sub(a, b)
   if is_int64(a) then
      if is_int64(b) then return new_int64(u64sub(a[1], a[2], b[1], b[2])) end
      a = int64.to_number(a)
   elseif is_int64(b) then b = int64.to_number(b) end
   return a - b
end

function int64.__mul(a, b)
   if is_int64(a) then
      if is_int64(b) then return new_int64(u64mul(a[1], a[2], b[1], b[2])) end
      a = int64.to_number(a)
   elseif is_int64(b) then b = int64.to_number(b) end
   return a * b
end

function int64.__div(a, b)
   if is_int64(a) then a = int64.to_number(a) end
   if is_int64(b) then b = int64.to_number(b) end
   return a / b
end

function int64.__mod(a, b)
   if is_int64(a) then
      if is_int64(b) then
         local _, _, r_l, r_h = i64div(a[1], a[2], b[1], b[2])
         return new_int64(r_l, r_h)
      end
      a = int64.to_number(a)
   elseif is_int64(b) then b = int64.to_number(b) end
   return a % b
end

function int64.__pow(a, b)
   if is_int64(a) then a = int64.to_number(a) end
   if is_int64(b) then b = int64.to_number(b) end
   return a ^ b
end

function int64.idiv(a, b)
   if is_int64(a) then
      if is_int64(b) then
         local r_l, r_h, m_l, m_h = i64div(a[1], a[2], b[1], b[2])
         return new_int64(r_l, r_h), new_int64(m_l, m_h)
      end
      a = int64.to_number(a)
   elseif is_int64(b) then b = int64.to_number(b) end
   return math.floor(a / b), a % b
end

function int64.bit_and(a, b)
   local a_l, a_h = to_int64(a)
   local b_l, b_h = to_int64(b)
   return new_int64(u32and(a_l, b_l), u32and(a_h, b_h))
end

function int64.bit_or(a, b)
   local a_l, a_h = to_int64(a)
   local b_l, b_h = to_int64(b)
   return new_int64(u32or(a_l, b_l), u32or(a_h, b_h))
end

function int64.bit_xor(a, b)
   local a_l, a_h = to_int64(a)
   local b_l, b_h = to_int64(b)
   return new_int64(u32xor(a_l, b_l), u32xor(a_h, b_h))
end

function int64.bit_not(a)
   local a_l, a_h = to_int64(a)
   return new_int64(u32not(a_l), u32not(a_h))
end

function int64.bit_shl(a, b)
   if is_int64(b) then b = int64.to_number(b) end
   return int64.bit_shr(a, -b)
end

function int64.bit_shr(a, b)
   if is_int64(b) then b = int64.to_number(b) end
   if b == 0 then return a end
   local a_l, a_h = to_int64(a)
   if b < 0 then
      if b <= -64 then return int64.zero end
      return new_int64(u64shl(a_l, a_h, -b))
   end
   if b > 64 then return int64.zero end
   return new_int64(u64shr(a_l, a_h, b))
end

local function reverse(tab)
   local i, j = 1, #tab
   while i < j do
      tab[i], tab[j] = tab[j], tab[i]
      i, j = i+1, j-1
   end
end

function int64.tostring(a, base)
   if base == nil then base = -10 end
   local prefix, suffix = "", ""
   local t_l, t_h = to_int64(a)
   if base < 0 then
      if t_h > 0x7FFFFFFF then
         prefix = "-"
         t_l, t_h = u64neg(t_l, t_h)
      end
      base = -base
   end
   assert(is_u32(base) and base <= 32 and base > 1)
   if t_h > 0 then
      local parts = {}
      local rem
      while t_h > 0 do
         t_l, t_h, rem = u64div(t_l, t_h, base, 0)
         parts[#parts+1] = string.sub("0123456789abcdefghijklmnopqrstuvwxyz", rem+1, rem+1)
      end
      reverse(parts)
      suffix = table.concat(parts)
   end
   if base == 10 then return string.format("%s%d%s", prefix, t_l, suffix) end
   local parts = {suffix}
   while t_l > 0 do
      local rem = t_l % base
      t_l = (t_l - rem) / base
      parts[#parts+1] = string.sub("0123456789abcdefghijklmnopqrstuvwxyz", rem+1, rem+1)
   end
   parts[#parts+1] = prefix
   reverse(parts)
   return table.concat(parts)
end

function int64:__tostring()
   return int64.tostring(self)
end

print(int64(0xFFFFFFFF, 0xFFFFFFF4):bit_shl(1):tostring(16))

return int64
