-- Copyright 2022 the LuaLiftoff project authors.
-- Use of this source code is governed by a MIT license that can be
-- found in the LICENSE file.

local Class = require"lualiftoff.util.class"

local inspect_with_ctx

local function header(ctx, obj)
   local class = Class:get_class(obj)
   if class then return class.name .. "[", "]", false end
   return "{", "}", true
end

local function inspect_table(ctx, parts, obj)
   local open, close, as_array = ctx.header(ctx, obj)
   local idx = #parts + 1
   parts[idx], idx = open, idx + 1

   local old_indent = ctx.indent
   local indent = " "

   if old_indent then
      indent = old_indent .. " "
      ctx.indent = indent
   end

   local seperator_indent = "," .. indent
   local seperator_indent_open = seperator_indent .. "["
   local max_int = as_array and 0 or -1
   local copy = {}
   local number_keys = {}
   local string_keys = {}
   local other_keys = {}

   for k, v in pairs(obj) do
      copy[k] = v
      local t = type(k)
      if t == "number" then
         number_keys[#number_keys+1] = k
         if max_int >= 0 and k > 0 and math.floor(k) == k then
            if k > max_int then
               max_int = k
            end
         else
            max_int = -2
         end
      elseif t == "string" then
         string_keys[#string_keys+1] = k
      else
         other_keys[#other_keys+1] = k
      end
   end

   if next(copy) == nil then
      parts[#parts+1] = close
      return
   end

   table.sort(string_keys)

   parts[idx], idx = indent, idx + 1

   for _, k in ipairs(string_keys) do
      local v = copy[k]
      if string.match(k, "^[A-Za-z_]+$") then
         parts[idx], parts[idx+1], idx = k, " = ", idx + 2
      else
         parts[idx], idx = string.format("[%q] = ", k), idx + 1
      end
      inspect_with_ctx(ctx, parts, v)
      idx = #parts + 1
      parts[idx], idx = seperator_indent, idx + 1
   end

   if max_int >= -1 and #other_keys == 0 and #number_keys * 2 >= max_int then
      for i = 1, max_int do
         local v = copy[i]
         inspect_with_ctx(ctx, parts, v)
         parts[#parts + 1] = seperator_indent
      end
   else
      assert(#number_keys > 0 or #other_keys > 0)
      table.sort(number_keys)

      parts[idx], idx = "[", idx + 1

      for _, k in ipairs(number_keys) do
         local v = copy[k]
         parts[idx], parts[idx+1], idx = tostring(k), "] = ", idx + 2
         inspect_with_ctx(ctx, parts, v)
         idx = #parts + 1
         parts[idx], idx = seperator_indent_open, idx + 1
      end

      for _, k in ipairs(other_keys) do
         local v = copy[k]
         inspect_with_ctx(ctx, parts, k)
         parts[#parts+1] = "] = "
         inspect_with_ctx(ctx, parts, v)
         parts[#parts+1] = seperator_indent_open
      end
   end

   if old_indent then
      parts[#parts] = old_indent
      parts[#parts+1] = close
      ctx.indent = old_indent
   else
      parts[#parts] = close
   end

end

local inspect_types = {
   ["table"] = inspect_table,
   ["string"] = function(ctx, parts, obj) parts[#parts+1] = string.format("%q", obj) end
}

function inspect_with_ctx(ctx, parts, obj)
   local t = inspect_types[type(obj)]
   if t then
      t(ctx, parts, obj)
   else
      parts[#parts+1] = tostring(obj)
   end
end

local function inspect(obj)
   local t = inspect_types[type(obj)]
   if not t then return tostring(obj) end
   local parts = {}
   local ctx = {header = header, indent = "\n"}
   t(ctx, parts, obj)
   return table.concat(parts)
end

return {
   inspect = inspect
}
