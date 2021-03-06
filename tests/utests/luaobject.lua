--[=[
 o-----------------------------------------------------------------------------o
 |
 | Object model (pure Lua) regression tests
 |
 | Methodical Accelerator Design - Copyright CERN 2016+
 | Support: http://cern.ch/mad  - mad at cern.ch
 | Authors: L. Deniau, laurent.deniau at cern.ch
 | Contrib: -
 |
 o-----------------------------------------------------------------------------o
 | You can redistribute this file and/or modify it under the terms of the GNU
 | General Public License GPLv3 (or later), as published by the Free Software
 | Foundation. This file is distributed in the hope that it will be useful, but
 | WITHOUT ANY WARRANTY OF ANY KIND. See http://gnu.org/licenses for details.
 o-----------------------------------------------------------------------------o

  Purpose:
  - Provide regression test suites for the object model without extension.

 o-----------------------------------------------------------------------------o
]=]

-- expected from other modules ------------------------------------------------o

local bit = require 'bit'
local band, bor, brol = bit.band, bit.bor, bit.rol

local btst = function (x,n) return band(x, brol( 1, n)) ~= 0 end
local bclr = function (x,n) return band(x, brol(-2, n))      end
local bset = function (x,n) return bor (x, brol( 1, n))      end

local metaname = { -- from lj_obj.h + __init + __exec + __totable
  '__add', '__call', '__concat', '__div', '__eq', '__exec', '__gc', '__index',
  '__init', '__ipairs', '__le', '__len', '__lt', '__metatable', '__mod',
  '__mode', '__mul', '__new', '__newindex', '__pairs', '__pow', '__sub',
  '__tostring', '__totable', '__unm',
}
for _,v in ipairs(metaname) do metaname[v]=v end -- build dictionary

local function is_nil (a)
  return type(a) == 'nil'
end

local function is_boolean (a)
  return type(a) == 'boolean'
end

local function is_number (a)
  return type(a) == 'number'
end

local function is_string (a)
  return type(a) == 'string'
end

local function is_function (a)
  return type(a) == 'function'
end

local function is_table (a)
  return type(a) == 'table'
end

local function is_rawtable (a)
  return type(a) == 'table' and getmetatable(a) == nil
end

local function is_metaname (a)
  return metaname[a] == a
end

local function is_callable (a)
  if type(a) == 'function' then return true end
  local mt = getmetatable(a)
  return mt and mt.__call ~= nil or false
end

-- implementation -------------------------------------------------------------o

-- module and metatable of objects
local M, MT = {}, {}

-- root of all objects
local Object

-- protected keys to object members, true functions, class and readonly flag
local var, fct, flg = {}, {}, {}, {}

-- flags (bit num)
local flg_ro, flg_cl = 0, 1

-- instance and metatable of 'incomplete objects' proxy
local var0 = setmetatable({}, {
  __index     = function() error "forbidden read access to incomplete object"  end,
  __newindex  = function() error "forbidden write access to incomplete object" end,
  __metatable = false,
})

-- metatable of 'true functions' proxy
local MF = {
  __call      = function(s,...) return s[fct](...) end,
  __metatable = false,
}

-- helpers

local function init (a)
  local m = rawget(getmetatable(a), '__init')
  return m and m(a) or a
end

local function parent (a)
  return getmetatable(rawget(a,'__index'))
end

local function fproxy (f)
  return setmetatable({[fct]=f}, MF)
end

local function fclass (a)
  return btst(rawget(a,flg) or 0, flg_cl)
end

local function freadonly (a)
  return btst(rawget(a,flg) or 0, flg_ro)
end

local function is_fproxy (a)
  return is_table(a) and rawget(a,fct) ~= nil
end

local function is_object (a)
  return is_table(a) and rawget(a,var) ~= nil
end

local function is_class (a) -- exported
  return is_table(a) and fclass(a)
end

local function is_readonly (a) -- exported
  return is_table(a) and freadonly(a)
end

local function set_class (a) -- not exported
  rawset(a,flg, bset(rawget(a,flg) or 0, flg_cl))
  return a
end

local function set_readonly (a, b)
  assert(a ~= Object, "invalid argument #1 (forbidden access to 'Object')")
  assert(is_nil(b) or is_boolean(b),
                      "invalid argument #2 (boolean or nil expected)")
  if b ~= false
  then rawset(a,flg, bset(rawget(a,flg) or 0, flg_ro))
  else rawset(a,flg, bclr(rawget(a,flg) or 0, flg_ro)) end
  return a
end

local function is_instanceOf (a, b)
  assert(is_object(b), "invalid argument #2 (object expected)")
  if not is_object(a) then return false end
  while a and a ~= b do a = parent(a) end
  return a == b
end

-- objects are proxies controlling variables access and inheritance

function MT:__call (a, b) -- object constructor (define the object-model)
  if is_string(a) then                                  -- named object
    if is_nil(b) then
      local obj = {__id=a, [var]=var0, __index=rawget(self,var)} -- proxy
      return setmetatable(obj, getmetatable(self))      -- incomplete object
    elseif is_rawtable(b) then
      local obj = {[var]=b, __index=rawget(self,var)}   -- proxy
      b.__id=a  setmetatable(b, obj)  set_class(self)   -- set fast inheritance
      return init(setmetatable(obj, getmetatable(self)))-- complete object
    end
  elseif is_rawtable(a) then
    if rawget(self,var) == var0 then                    -- finalize named object
      a.__id, self.__id = self.__id
      rawset(self,var, setmetatable(a, self));          -- set fast inheritance
      set_class(parent(self))
      return init(self)
    else                                                -- unnamed object
      local obj = {[var]=a, __index=rawget(self,var)}   -- proxy
      setmetatable(a, obj)  set_class(self)             -- set fast inheritance
      return init(setmetatable(obj, getmetatable(self)))-- complete object
    end
  end
  error(is_nil(b)
        and "invalid argument #1 to constructor (string or raw table expected)"
        or  "invalid argument #2 to constructor (raw table expected)")
end

function MT:__index (k)
  local v = rawget(self,var)[k]                      -- inheritance of variables
  if is_function(v)
  then return v(self)                            -- function with value semantic
  else return v end
end

function MT:__newindex (k, v)
  assert(not freadonly(self), "forbidden write access to readonly object")
  rawget(self,var)[k] = v
end

function MT:__len ()
  return #rawget(self,var)
end

local function iterk (self, k)
  local v
  k, v = next(rawget(self,var), k)
  if is_function(v)
  then return k, v(self)
  else return k, v end
end

function MT:__pairs ()
  return iterk, self, nil
end

local function iteri (self, i)
  i = i + 1
  local v = rawget(rawget(self,var), i)
  if is_function(v) then return i, v(self)
  elseif v ~= nil   then return i, v end
end

function MT:__ipairs()
  return iteri, self, 0
end

local function get_variable (self, tbl, eval)
  assert(is_object(self) , "invalid argument #1 (object expected)")
  assert(is_rawtable(tbl), "invalid argument #2 (raw table expected)")
  local var, res = rawget(self,var), {}
  if eval ~= false
  then for _,k in ipairs(tbl) do res[k] = self[k] end
  else for _,k in ipairs(tbl) do res[k] = var [k] end
  end
  return res
end

local function set_variable (self, tbl, override)
  assert(is_object(self) , "invalid argument #1 (object expected)")
  assert(is_rawtable(tbl), "invalid argument #2 (raw table expected)")
  local var = rawget(self,var)
  for k,v in pairs(tbl) do
    assert(is_nil(rawget(var,k)) or override~=false, "cannot override variable")
    rawset(var, k, v)
  end
  return self
end

local function set_function (self, tbl, override, strict)
  assert(is_object(self) , "invalid argument #1 (object expected)")
  assert(is_rawtable(tbl), "invalid argument #2 (raw table expected)")
  local var = rawget(self,var)
  for k,f in pairs(tbl) do
    assert(is_callable(f) or strict==false, "invalid value (callable expected)")
    assert(is_nil(rawget(var,k)) or override~=false, "cannot override function")
    rawset(var, k, is_function(f) and fproxy(f) or f)
  end
  return self
end

local function set_metamethod (self, tbl, override, strict)
  assert(is_object(self) , "invalid argument #1 (object expected)")
  assert(is_rawtable(tbl), "invalid argument #2 (raw table expected)")
  local sm, pm = getmetatable(self), getmetatable(parent(self)) or MT
  if sm == pm then -- create new metatable if same as parent
    assert(not fclass(self), "invalid metatable (class unexpected)")
    sm={} for k,v in pairs(pm) do sm[k] = v end
  end
  for k,mm in pairs(tbl) do
    assert(is_metaname(k) or strict==false, "invalid key (metamethod expected)")
    assert(is_nil(rawget(sm,k)) or override==true, "cannot override metamethod")
    rawset(sm, k, mm)
  end
  return setmetatable(self, sm)
end

local function get_varkey (self, class, pattern)
  class, pattern = class or Object, pattern or ''
  assert(is_object(self)   , "invalid argument #1 (object expected)")
  assert(is_object(class)  , "invalid argument #2 (object expected)")
  assert(is_string(pattern), "invalid argument #3 (string expected)")
  local key = {}
  while self and self ~= class do
    for k in pairs(rawget(self,var)) do key[k] = k end
    self = parent(self)
  end
  assert(self == class, "invalid argument #2 (parent of argument #1 expected)")
  local res = {}
  for k in pairs(key) do
    if is_string(k) and string.find(k, pattern) then
      res[#res+1] = k
    end
  end
  return res
end

local function strdump (self, class, pattern)
  class, pattern = class or Object, pattern or ''
  assert(is_object(self)   , "invalid argument #1 (object expected)")
  assert(is_object(class)  , "invalid argument #2 (object expected)")
  assert(is_string(pattern), "invalid argument #3 (string expected)")
  local cnt, res, spc, str = {}, {}, ""
  while self and self ~= class do
    local vars = rawget(self,var)
    -- header
    str = rawget(vars, '__id') and (" '"..vars.__id.."'") or ""
    res[#res+1] = spc.."+ ["..tostring(vars).."]"..str
    spc = spc .. "  "
    -- variables
    for k,v in pairs(vars) do
      if is_string(k) and k ~= '__id' and string.find(k, pattern) then
        str = spc .. tostring(k)
            if is_string(v) then str = str..": '"..tostring(v):sub(1,15).."'"
        elseif is_fproxy(v) then str = str..": ["..tostring(v[fct]).."]"
        else                     str = str..":  "..tostring(v) end
        if cnt[k]
        then str = str.." ("..string.rep('*', cnt[k])..")" -- mark overrides
        else cnt[k] = 0 end
        cnt[k] = cnt[k] + 1
        res[#res+1] = str
      end
    end
    self = parent(self)
  end
  assert(self == class, "invalid argument #2 (parent of argument #1 expected)")
  res[#res+1] = ''
  return table.concat(res, '\n')
end

-- TODO: show command...

-- root Object variables = module
Object = setmetatable({[var]=M, [flg]=bset(0,flg_ro)},MT)

 -- parent link
setmetatable(M, Object)

-- methods
M.is_class       = fproxy( is_class       )
M.is_readonly    = fproxy( is_readonly    )
M.is_instanceOf  = fproxy( is_instanceOf  )
M.set_readonly   = fproxy( set_readonly   )
M.get_varkey     = fproxy( get_varkey     )
M.get_variable   = fproxy( get_variable   )
M.set_variable   = fproxy( set_variable   )
M.set_function   = fproxy( set_function   )
M.set_metamethod = fproxy( set_metamethod )
M.strdump        = fproxy( strdump        )

-- aliases
M.get, M.getk, M.set, M.setf, M.setmm = M.get_variable, M.get_varkey,
  M.set_variable, M.set_function, M.set_metamethod

-- members
M.__id   = 'Object'
M.__par  = parent
M.__var  = function(s) return rawget(s,var) end -- alias
M.name   = function(s) return s.__id end        -- alias
M.parent = function(s) return s.__par end       -- alias

-- end of object model --------------------------------------------------------o

local assertEquals, assertAlmostEquals, assertErrorMsgContains, assertNil,
      assertTrue, assertFalse, assertNotEquals, assertStrContains in MAD.utest

-- regression test suite ------------------------------------------------------o

TestLuaObject = {}

function TestLuaObject:testConstructor()
  local p0 = Object 'p0' {}
  local p1 = Object {}
  local p2 = Object 'p2'
  local p3 = Object
  local p4 = Object('p4',{})

  local p00 = p0 'p00' {}
  local p01 = p0 {}
  local p02 = p0 'p02'
  local p03 = p0
  local p04 = p0('p04',{})

  local get = function(s,k) return s[k] end
  local set = function(s,k,v) s[k]=v end
  local msg = {
    "forbidden read access to incomplete object",
    "forbidden write access to incomplete object",
    "forbidden write access to readonly object",
    "invalid argument #1 to constructor (string or raw table expected)",
    "invalid argument #2 to constructor (raw table expected)"
  }

  -- invalid ctor argument
  assertErrorMsgContains(msg[4], Object, true)
  assertErrorMsgContains(msg[4], Object, 1)
  assertErrorMsgContains(msg[4], Object, function() end)
  assertErrorMsgContains(msg[4], Object, Object)
  assertErrorMsgContains(msg[5], Object, 'p', true)
  assertErrorMsgContains(msg[5], Object, 'p', 1)
  assertErrorMsgContains(msg[5], Object, 'p', '1')
  assertErrorMsgContains(msg[5], Object, 'p', function() end)
  assertErrorMsgContains(msg[5], Object, 'p', Object)

  -- ctor equivalence
  assertEquals(p4, Object 'p4' {})
  assertEquals(p04, p0 'p04' {})

  -- read
  assertNil( p0.a )
  assertNil( p1.a )
  assertErrorMsgContains(msg[1], get, p2, a)
  assertNil( p3.a )
  assertNil( p4.a )

  -- write
  p0.a = ''   assertEquals( p0.a, '' )
  p1.a = ''   assertEquals( p1.a, '' )
  assertErrorMsgContains(msg[2], set, p2, a, '')
  assertErrorMsgContains(msg[3], set, p3, a, '')
  p4.a = ''   assertEquals( p4.a, '' )

  -- read child
  assertEquals( p00.a, '' )
  assertEquals( p01.a, '' )
  assertErrorMsgContains(msg[1], get, p02, a)
  assertEquals( p03.a, '' )
  assertEquals( p04.a, '' )

  -- write child
  p00.a = '0'   assertEquals( p00.a, '0' )
  p01.a = '0'   assertEquals( p01.a, '0' )
  assertErrorMsgContains(msg[2], set, p02, a, '')
  p03.a = '0'   assertEquals( p03.a, '0' )
  p04.a = '0'   assertEquals( p04.a, '0' )
end

function TestLuaObject:testIsObject()
  local p0 = Object 'p0' {}
  local p1 = Object {}
  local p2 = Object 'p2'
  local p3 = Object

  local p00 = p0 'p00' {}
  local p01 = p0 {}
  local p02 = p0 'p02'
  local p03 = p0

  assertTrue ( is_object(p0) )
  assertTrue ( is_object(p1) )
  assertTrue ( is_object(p2) )
  assertTrue ( is_object(p3) )
  assertTrue ( is_object(p00) )
  assertTrue ( is_object(p01) )
  assertTrue ( is_object(p02) )
  assertTrue ( is_object(p03) )
  assertFalse( is_object(nil)  )
  assertFalse( is_object(1)    )
  assertFalse( is_object({})   )
  assertFalse( is_object(function() end) )
end

function TestLuaObject:testIsReadonly()
  local p0 = Object 'p0' {}
  local p1 = Object {}
  local p2 = Object 'p2'
  local p3 = Object

  local p00 = p0 'p00' {}
  local p01 = p0 {}
  local p02 = p0 'p02'
  local p03 = p0

  local msg = {
    "invalid argument #1 (forbidden access to 'Object')",
    "invalid argument #2 (boolean or nil expected)",
    "invalid argument #1 (forbidden access to 'ro_obj')",
  }

  assertFalse( is_readonly(p0)  )
  assertFalse( is_readonly(p1)  )
  assertFalse( is_readonly(p2)  )
  assertTrue ( is_readonly(p3)  )
  assertFalse( is_readonly(p00) )
  assertFalse( is_readonly(p01) )
  assertFalse( is_readonly(p02) )
  assertFalse( is_readonly(p03) )
  assertTrue ( is_readonly(p03:set_readonly(true)) )
  p0:set_readonly(true)
  assertTrue ( p0:is_readonly()  )
  assertFalse( p00:is_readonly() )
  assertErrorMsgContains(msg[1], Object.set_readonly, Object, true)
  assertErrorMsgContains(msg[1], Object.set_readonly, Object, false)
  assertErrorMsgContains(msg[2], p0.set_readonly, p0, 1)
  assertErrorMsgContains(msg[2], p00.set_readonly, p0, '')
end

function TestLuaObject:testInheritance()
  local p0 = Object {}
  local p1 = p0 { x=3, y=2, z=1  }
  local p2 = p1 { x=2, y=1 }
  local p3 = p2 { x=1  }
  local p4 = p3 { }
  local vs = {'x','y','z'}

  assertEquals   ( p0:get(vs), {} )
  assertEquals   ( p0        , {} )

  assertEquals   ( p1:get(vs), { x=3, y=2, z=1 } )
  assertEquals   ( p1        , { x=3, y=2, z=1 } )
  assertNotEquals( p1        , { x=3, y=2 } )

  assertEquals   ( p2:get(vs), { x=2, y=1, z=1 } )
  assertEquals   ( p2        , { x=2, y=1 } )
  assertNotEquals( p2        , { x=2 } )

  assertEquals   ( p3:get(vs), { x=1, y=1, z=1 } )
  assertEquals   ( p3        , { x=1 } )
  assertNotEquals( p3        , { x=1, y=1 } )

  assertEquals   ( p4:get(vs), { x=1, y=1, z=1 } )
  assertEquals   ( p4        , {} )
  assertNotEquals( p4        , { x=1 } )

  assertEquals   ( {p1.x, p1.y, p1.z}, {3,2,1})
  assertEquals   ( {p2.x, p2.y, p2.z}, {2,1,1})
  assertEquals   ( {p3.x, p3.y, p3.z}, {1,1,1})
  assertEquals   ( {p4.x, p4.y, p4.z}, {1,1,1})

  p2:set{x=5, y=6}  p4:set{y=5, z=6}

  assertEquals   ( p0:get(vs), {} )
  assertEquals   ( p0        , {} )

  assertEquals   ( p1:get(vs), { x=3, y=2, z=1 } )
  assertEquals   ( p1        , { x=3, y=2, z=1 } )
  assertNotEquals( p1        , { x=3, y=2 } )

  assertEquals   ( p2:get(vs), { x=5, y=6, z=1 } )
  assertEquals   ( p2        , { x=5, y=6 } )
  assertNotEquals( p2        , { x=5 } )
  assertNotEquals( p2        , { x=2, y=1 } )

  assertEquals   ( p3:get(vs), { x=1, y=6, z=1 } )
  assertEquals   ( p3        , { x=1 } )
  assertNotEquals( p3        , { x=1, y=6 } )
  assertNotEquals( p3        , { x=1, y=1 } )

  assertEquals   ( p4:get(vs), { x=1, y=5, z=6 } )
  assertEquals   ( p4        , { y=5, z=6 } )
  assertNotEquals( p4        , { x=1 } )

  assertEquals   ( {p1.x, p1.y, p1.z}, {3,2,1})
  assertEquals   ( {p2.x, p2.y, p2.z}, {5,6,1})
  assertEquals   ( {p3.x, p3.y, p3.z}, {1,6,1})
  assertEquals   ( {p4.x, p4.y, p4.z}, {1,5,6})
end

function TestLuaObject:testIsInstanceOf()
  local p0 = Object {}
  local p1 = p0 { }
  local p2 = p1 { }
  local p3 = p1 { }
  local p4 = p3 { }

  local msg = {
    "invalid argument #2 (object expected)",
  }

  assertTrue ( Object:is_instanceOf(Object) )

  assertTrue ( p0:is_instanceOf(Object) )
  assertTrue ( p0:is_instanceOf(p0) )
  assertFalse( p0:is_instanceOf(p1) )
  assertFalse( p0:is_instanceOf(p2) )
  assertFalse( p0:is_instanceOf(p3) )
  assertFalse( p0:is_instanceOf(p4) )

  assertTrue ( p1:is_instanceOf(Object) )
  assertTrue ( p1:is_instanceOf(p0) )
  assertTrue ( p1:is_instanceOf(p1) )
  assertFalse( p1:is_instanceOf(p2) )
  assertFalse( p1:is_instanceOf(p3) )
  assertFalse( p1:is_instanceOf(p4) )

  assertTrue ( p2:is_instanceOf(Object) )
  assertTrue ( p2:is_instanceOf(p0) )
  assertTrue ( p2:is_instanceOf(p1) )
  assertTrue ( p2:is_instanceOf(p2) )
  assertFalse( p2:is_instanceOf(p3) )
  assertFalse( p2:is_instanceOf(p4) )

  assertTrue ( p3:is_instanceOf(Object) )
  assertTrue ( p3:is_instanceOf(p0) )
  assertTrue ( p3:is_instanceOf(p1) )
  assertFalse( p3:is_instanceOf(p2) )
  assertTrue ( p3:is_instanceOf(p3) )
  assertFalse( p3:is_instanceOf(p4) )

  assertTrue ( p4:is_instanceOf(Object) )
  assertTrue ( p4:is_instanceOf(p0) )
  assertTrue ( p4:is_instanceOf(p1) )
  assertFalse( p4:is_instanceOf(p2) )
  assertTrue ( p4:is_instanceOf(p3) )
  assertTrue ( p4:is_instanceOf(p4) )

  assertFalse( is_instanceOf(0 , p0) )
  assertFalse( is_instanceOf('', p0) )
  assertFalse( is_instanceOf({}, p0) )

  assertErrorMsgContains(msg[1], is_instanceOf, p0, 0)
  assertErrorMsgContains(msg[1], is_instanceOf, p0, '')
  assertErrorMsgContains(msg[1], is_instanceOf, p0, {})
end

function TestLuaObject:testValueSemantic()
  local p0 = Object {}
  local p1 = p0 { x=3, y=2, z=function(s) return 2*s.y end}
  local p2 = p1 { x=2, y=function(s) return 3*s.x end }
  local p3 = p2 { x=function() return 5 end }
  local p4 = p3 { }
  local vs = {'x','y','z'}

  assertEquals   ( p0 , {} )
  assertEquals   ( p1:get(vs)      , { x=3, y=2, z=4 } )
  assertNotEquals( p1:get(vs,false), { x=3, y=2, z=4 } )
  assertNotEquals( p1:get(vs)      , { x=3, y=2 } )
  assertEquals   ( p2:get(vs)      , { x=2, y=6, z=12 } )
  assertNotEquals( p2:get(vs,false), { x=2, y=6, z=12 } )
  assertNotEquals( p2:get(vs)      , { x=2, y=6 } )
  assertNotEquals( p2:get(vs)      , { x=3, y=2 } )
  assertEquals   ( p3:get(vs)      , { x=5, y=15, z=30 } )
  assertNotEquals( p3:get(vs,false), { x=5, y=15, z=30 } )
  assertNotEquals( p3:get(vs)      , { x=5, y=15 } )
  assertNotEquals( p3:get(vs)      , { x=2, y=6 } )
  assertEquals   ( p4:get(vs)      , { x=5, y=15, z=30 } )
  assertNotEquals( p4:get(vs,false), { x=5, y=15, z=30 } )
  assertNotEquals( p4:get(vs)      , { x=5, y=15 } )

  p1.z = 6
  assertEquals   ( p1:get(vs)      , { x=3, y=2, z=6 } )
  assertEquals   ( p1:get(vs,false), { x=3, y=2, z=6 } )
  assertNotEquals( p1:get(vs)      , { x=3, y=2 } )
  assertEquals   ( p2:get(vs)      , { x=2, y=6, z=6 } )
  assertNotEquals( p2:get(vs,false), { x=2, y=6, z=6 } )
  assertNotEquals( p2:get(vs)      , { x=2, y=6 } )
  assertEquals   ( p3:get(vs)      , { x=5, y=15, z=6 } )
  assertNotEquals( p3:get(vs,false), { x=5, y=15, z=6 } )
  assertEquals   ( p3:get(vs)      , { x=5, y=15, z=6 } )
  assertEquals   ( p4:get(vs)      , { x=5, y=15, z=6 } )
  assertNotEquals( p4:get(vs,false), { x=5, y=15, z=6 } )
  assertNotEquals( p4:get(vs)      , { x=5, y=15 } )

  p2.y = 5
  assertEquals   ( p2:get(vs)      , { x=2, y=5, z=6 } )
  assertEquals   ( p2:get(vs,false), { x=2, y=5, z=6 } )
  assertNotEquals( p2:get(vs)      , { x=2, y=5 } )
  assertEquals   ( p3:get(vs)      , { x=5, y=5, z=6 } )
  assertNotEquals( p3:get(vs,false), { x=5, y=5, z=6 } )
  assertEquals   ( p3:get(vs)      , { x=5, y=5, z=6 } )
  assertEquals   ( p4:get(vs)      , { x=5, y=5, z=6 } )
  assertNotEquals( p4:get(vs,false), { x=5, y=5, z=6 } )
  assertNotEquals( p4:get(vs)      , { x=5, y=5 } )

  p3.x = 3
  assertEquals   ( p3:get(vs)      , { x=3, y=5, z=6 } )
  assertEquals   ( p3:get(vs,false), { x=3, y=5, z=6 } )
  assertNotEquals( p3:get(vs)      , { x=3, y=5 } )
  assertEquals   ( p4:get(vs)      , { x=3, y=5, z=6 } )
  assertEquals   ( p4:get(vs,false), { x=3, y=5, z=6 } )
  assertNotEquals( p4:get(vs)      , { x=3, y=5 } )
end

function TestLuaObject:testArrayValueSemantic()
  local p0 = Object {}
  local p1 = p0 { x=3, y=2, z=function(s) return { x=3*s.x, y=2*s.y } end }
  local p2 = p1 { x=2, y=function(s) return 2*s.x end }
  local p3 = p2 { x=function() return 5 end }
  local p4 = p3 {}
  local vs = {'x','y','z'}

  assertEquals   ( p0 , {} )
  assertEquals   ( p1:get(vs)      , { x=3, y=2, z={x=9, y=4} } )
  assertNotEquals( p1:get(vs,false), { x=3, y=2, z={x=9, y=4} } )
  assertNotEquals( p1:get(vs)      , { x=3, y=2 } )
  assertEquals   ( p2:get(vs)      , { x=2, y=4, z={x=6,y=8} } )
  assertNotEquals( p2:get(vs,false), { x=2, y=6, z={x=6,y=8} } )
  assertNotEquals( p2:get(vs)      , { x=2, y=6 } )
  assertNotEquals( p2:get(vs)      , { x=3, y=2 } )
  assertEquals   ( p3:get(vs)      , { x=5, y=10, z={x=15,y=20} } )
  assertNotEquals( p3:get(vs,false), { x=5, y=10, z={x=15,y=20} } )
  assertNotEquals( p3:get(vs)      , { x=5, y=15 } )
  assertNotEquals( p3:get(vs)      , { x=2, y=6 } )
  assertEquals   ( p4:get(vs)      , { x=5, y=10, z={x=15,y=20} } )
  assertNotEquals( p4:get(vs,false), { x=5, y=15, z={x=15,y=20} } )
  assertNotEquals( p4:get(vs)      , { x=5, y=15 } )

  p1:set { x=function() return 7 end }
  assertEquals   ( p1:get(vs)      , { x=7, y=2, z={x=21,y=4} } )
  assertNotEquals( p1:get(vs,false), { x=7, y=2, z={x=21,y=4} } )
  assertNotEquals( p1:get(vs)      , { x=7, y=2 } )
  assertNotEquals( p1:get(vs)      , { y=2 } )
  assertEquals   ( p2:get(vs)      , { x=2, y=4, z={x=6,y=8} } )
  assertNotEquals( p2:get(vs,false), { x=2, y=4, z={x=6,y=8} } )
  assertNotEquals( p2:get(vs)      , { x=2, y=6 } )
  assertEquals   ( p3:get(vs)      , { x=5, y=10, z={x=15,y=20} } )
  assertNotEquals( p3:get(vs,false), { x=5, y=15, z=6 } )
  assertNotEquals( p3:get(vs)      , { x=5, y=15 } )
  assertEquals   ( p4:get(vs)      , { x=5, y=10, z={x=15,y=20} } )
  assertNotEquals( p4:get(vs,false), { x=5, y=15, z={x=15,y=20} } )
  assertNotEquals( p4:get(vs)      , { x=5, y=15 } )
end

function TestLuaObject:testSpecialVariable()
  local p0 = Object 'p0' {}
  local p1 = p0 { x=3, y=function(s) return 2*s.x end, z=function(s) return { x=3*s.x, y=2*s.y } end }
  local p2 = p1 { x=2, y=function(s) return 4*s.x end }
  local p3 = p2 { x=function() return 5 end }
  local p4 = p3 {}

  assertTrue     ( p0.parent == Object )
  assertTrue     ( p1.parent == p0 )
  assertTrue     ( p2.parent == p1 )
  assertTrue     ( p3.parent == p2 )
  assertTrue     ( p4.parent == p3 )
  assertTrue     ( p0.parent == p0.__par )
  assertTrue     ( p1.parent == p1.__par )
  assertTrue     ( p2.parent == p2.__par )
  assertTrue     ( p3.parent == p3.__par )
  assertTrue     ( p4.parent == p4.__par )

  assertEquals   ( p0.name , 'p0' )
  assertEquals   ( p1.name , 'p0' )
  assertEquals   ( p0      , { __id='p0' } )
  assertEquals   ( p1.__id , 'p0' )

  assertEquals   ( p0.parent.name , 'Object' )
  assertTrue     ( p0.parent:is_readonly() )
  assertFalse    ( p0:is_readonly() )

  assertEquals   ( p1.__var.x      , p1.x )
  assertEquals   ( p1.__var.y(p1)  , p1.y )
  assertNotEquals( p1.__var.y(p2)  , p1.y )
  assertEquals   ( p1.__var.z(p1).x, p1.z.x )
  assertEquals   ( p1.__var.z(p1).y, p1.z.y )
  assertNotEquals( p1.__var.z(p2).y, p1.z.y )

  assertEquals   ( p2.__var.x      , p2.x )
  assertEquals   ( p2.__var.y(p2)  , p2.y )
  assertNotEquals( p2.__var.y(p1)  , p2.y )
  assertEquals   ( p2.__var.z(p2).x, p2.z.x )
  assertEquals   ( p2.__var.z(p2).y, p2.z.y )
  assertNotEquals( p2.__var.z(p3).y, p2.z.y )

  assertEquals   ( p3.__var.x(p3)  , p3.x )
  assertEquals   ( p3.__var.y(p3)  , p3.y )
  assertNotEquals( p3.__var.y(p2)  , p3.y )
  assertEquals   ( p3.__var.z(p3).x, p3.z.x )
  assertEquals   ( p3.__var.z(p3).y, p3.z.y )
  assertEquals   ( p3.__var.z(p4).y, p3.z.y )

  assertEquals   ( p4.__var.x(p4)  , p4.x )
  assertEquals   ( p4.__var.y(p4)  , p4.y )
  assertEquals   ( p4.__var.y(p3)  , p4.y )
  assertEquals   ( p4.__var.z(p4).x, p4.z.x )
  assertEquals   ( p4.__var.z(p4).y, p4.z.y )

  assertEquals   ( p2.__par.__var.x      , p1.x )
  assertEquals   ( p2.__par.__var.y(p1)  , p1.y )
  assertEquals   ( p2.__par.__var.z(p1).x, p1.z.x )
  assertEquals   ( p2.__par.__var.z(p1).y, p1.z.y )
  assertNotEquals( p2.__par.__var.z(p2).y, p1.z.y )

  assertEquals   ( p3.__par.__var.x      , p2.x )
  assertEquals   ( p3.__par.__var.y(p2)  , p2.y )
  assertEquals   ( p3.__par.__var.z(p2).x, p2.z.x )
  assertEquals   ( p3.__par.__var.z(p2).y, p2.z.y )
  assertNotEquals( p3.__par.__var.z(p3).y, p2.z.y )

  assertEquals   ( p4.__par.__var.x()    , p3.x )
  assertEquals   ( p4.__par.__var.y(p3)  , p3.y )
  assertEquals   ( p4.__par.__var.z(p3).x, p3.z.x )
  assertEquals   ( p4.__par.__var.z(p3).y, p3.z.y )
  assertEquals   ( p4.__par.__var.z(p4).y, p3.z.y )
end

function TestLuaObject:testIterators()
  local p0 = Object 'p0' { 2, 3, 4, x=1, y=2, z=function() return 3 end}
  local p1 = p0 'p1' { 7, 8, x=-1, y={} }
  local c

  assertEquals(#p0, 3)
  assertEquals(#p1, 2)

  c=0 for k,v in  pairs(p0) do c=c+1 assertEquals(p0[k], v) end
  assertEquals(c , 7)
  c=0 for k,v in  pairs(p1) do c=c+1 assertEquals(p1[k], v) end
  assertEquals(c , 5)
  c=0 for i,v in ipairs(p0) do c=c+1 assertEquals(p0[i], v) end
  assertEquals(c , 3)
  c=0 for i,v in ipairs(p1) do c=c+1 assertEquals(p1[i], v) end
  assertEquals(c , 2)
  c=0 for i=1,#p0           do c=c+1 assertEquals(p0[i], i+1) end
  assertEquals(c , 3)
  c=0 for i=1,#p1           do c=c+1 assertEquals(p1[i], i+6) end
  assertEquals(c , 2)
  c=1 while p0[c]           do c=c+1 assertEquals(p0[c-1], c) end
  assertEquals(c , 4)
  c=1 while p1[c]           do c=c+1 assertEquals(p1[c-1]%5, c) end
  assertEquals(c , 4)

  -- bypass function evaluation, v may be a function but loops get same length
  c=0 for k,v in  pairs(p0.__var) do c=c+1 assertEquals(p0.__var[k], v) end
  assertEquals(c , 7)
  c=0 for k,v in  pairs(p1.__var) do c=c+1 assertEquals(p1.__var[k], v) end
  assertEquals(c , 5)
  c=0 for i,v in ipairs(p0.__var) do c=c+1 assertEquals(p0.__var[i], v) end
  assertEquals(c , 3)
  c=0 for i,v in ipairs(p1.__var) do c=c+1 assertEquals(p1.__var[i], v) end
  assertEquals(c , 2)
  c=0 for i=1,#p0.__var           do c=c+1 assertEquals(p0.__var[i], i+1) end
  assertEquals(c , 3)
  c=0 for i=1,#p1.__var           do c=c+1 assertEquals(p1.__var[i], i+6) end
  assertEquals(c , 2)
  c=1 while p0.__var[c]           do c=c+1 assertEquals(p0.__var[c-1], c) end
  assertEquals(c , 4)
  c=1 while p1.__var[c]           do c=c+1 assertEquals(p1.__var[c-1]%5, c) end
  assertEquals(c , 4)
end

function TestLuaObject:testGetVariable()
  local p0 = Object 'p0' { x=1, y=2, z=function() return 3 end }
  local p1 = p0 'p1' { x=-1, y={} }
  local vs = {'name', 'x','y','z'}
  local msg = {
    "invalid argument #1 (object expected)",
    "invalid argument #2 (raw table expected)",
  }

  assertEquals ( p0:get(vs), { name='p0', x=1 , y=2 , z=3 } )
  assertEquals ( p1:get(vs), { name='p1', x=-1, y={}, z=3 } )

  assertEquals ( p0.get(p0,vs), { name='p0', x=1 , y=2 , z=3 } )
  assertEquals ( p1.get(p1,vs), { name='p1', x=-1, y={}, z=3 } )

  assertEquals ( p0:get(vs, true ).z, 3 )
  assertEquals ( p0:get(vs, nil  ).z, 3 )

  assertTrue  ( is_function(p0:get(vs, false).name) )
  assertTrue  ( is_function(p0:get(vs, false).z) )
  assertFalse ( is_function(p0:get(vs, nil  ).z) )

  assertTrue  ( is_function(p1:get(vs, false).name) )
  assertTrue  ( is_function(p1:get(vs, false).z) )
  assertTrue  ( is_table   (p1:get(vs, false).y) )
  assertTrue  ( is_table   (p1:get(vs, true ).y) )

  assertErrorMsgContains(msg[1], p0.get, 1, vs)
  assertErrorMsgContains(msg[1], p0.get, {}, vs)
  assertErrorMsgContains(msg[2], p0.get, p0, 1)
end

function TestLuaObject:testSetVariable()
  local p0 = Object 'p0' {}
  local p1 = p0 'p1' {}
  local vs = {'name', 'x','y','z'}
  local msg = {
    "invalid argument #1 (object expected)",
    "invalid argument #2 (raw table expected)",
    "cannot override variable",
  }

  p0:set { x=1, y=2, z=function() return 3 end }
  p1:set { x=-1, y={} }

  assertEquals ( p0:get(vs), { name='p0', x=1 , y=2 , z=3 } )
  assertEquals ( p1:get(vs), { name='p1', x=-1, y={}, z=3 } )

  assertEquals ( p0.get(p0,vs), { name='p0', x=1 , y=2 , z=3 } )
  assertEquals ( p1.get(p1,vs), { name='p1', x=-1, y={}, z=3 } )

  assertEquals(             p0:get(vs, true ).z, 3 )
  assertEquals(             p0:get(vs, nil  ).z, 3 )

  assertTrue  ( is_function(p0:get(vs, false).name) )
  assertTrue  ( is_function(p0:get(vs, false).z) )
  assertFalse ( is_function(p0:get(vs, nil  ).z) )

  assertTrue  ( is_function(p1:get(vs, false).name) )
  assertTrue  ( is_function(p1:get(vs, false).z) )
  assertTrue  ( is_table   (p1:get(vs, false).y) )
  assertTrue  ( is_table   (p1:get(vs, true ).y) )

  assertErrorMsgContains(msg[1], p0.set, 1)
  assertErrorMsgContains(msg[1], p0.set, '')
  assertErrorMsgContains(msg[1], p0.set, {})

  assertErrorMsgContains(msg[2], p0.set, p0, 1)
  assertErrorMsgContains(msg[2], p0.set, p0, '')

  assertErrorMsgContains(msg[3], p0.set, p0, {x=2}, false)
  assertErrorMsgContains(msg[3], p1.set, p1, {y=2}, false)

  p1:set { z=5 }
  assertEquals( p1:get(vs, true).z, 5 )
  assertErrorMsgContains(msg[3], p1.set, p1, {z=2}, false)
end

function TestLuaObject:testSetFunction()
  local p0 = Object 'p0' { z=function() return 3 end }
  local p1 = p0 'p1' {}
  local msg = {
    "invalid argument #1 (object expected)",
    "invalid argument #2 (raw table expected)",
    "invalid value (callable expected)",
    "cannot override function",
  }
  p0:set_function { x=function() return 2 end, y=function(s,n) return s.z*n end }

  assertFalse ( is_function(p0.x) )
  assertFalse ( is_function(p0.y) )
  assertFalse ( is_function(p0.z) )
  assertEquals( p0.z, 3 )
  assertFalse ( is_function(p0:get{'z'}.z) )
  assertTrue  ( is_function(p0:get({'z'},false).z) )
  assertTrue  ( is_function(p0.__var.z) )

  assertFalse ( is_function(p1.x) )
  assertFalse ( is_function(p1.y) )
  assertFalse ( is_function(p1.z) )
  assertEquals( p1.x(), 2)
  assertEquals( p1:y(3), 9)

  assertTrue  ( is_table(p1.x) )
  assertTrue  ( is_table(p1.y) )
  assertTrue  ( is_number(p1.z) )

  p1:set_function({ x=function() return function() return 2 end end, y =function(s) return function(n) return s.z*n end end })

  assertTrue  ( is_table   (p1.x) )
  assertTrue  ( is_function(p1.x()) )
  assertEquals( p1.x()(), 2)

  assertTrue  ( is_table   (p1.y) )
  assertTrue  ( is_function(p1:y()) )
  assertEquals( p1:y()(3), 9)

  p1.y = function(s) return function(n) return s.z*n end end
  assertFalse ( is_table   (p1.y) )
  assertTrue  ( is_function(p1.y) )
  assertFalse ( is_function(p1.y(3)) )
  assertEquals( p1.y(3), 9)

  assertErrorMsgContains(msg[1], p0.setf, 1)
  assertErrorMsgContains(msg[1], p0.setf, '')
  assertErrorMsgContains(msg[1], p0.setf, {})

  assertErrorMsgContains(msg[2], p0.setf, p0, 1)
  assertErrorMsgContains(msg[2], p0.setf, p0, '')

  assertErrorMsgContains(msg[3], p0.setf, p0, {x=1})
  assertErrorMsgContains(msg[3], p0.setf, p0, {x=''})

  assertErrorMsgContains(msg[4], p0.setf, p0, {x=function() return 3 end}, false)
end

local count = 0

function TestLuaObject:testSetMetamethod()
  local msg = {
    "invalid argument #1 (object expected)",
    "invalid argument #2 (raw table expected)",
    "invalid metatable (class unexpected)",
    "invalid key (metamethod expected)",
    "cannot override metamethod",
  }
  local tostr = function(s)
      local str = ''
      for k,v in pairs(s) do str = str .. tostring(k) .. ', ' end
      return str
    end

  local p0, p1
  p0 = Object 'p0' { 1, 2, z=function() return 3 end }
  p1 = p0 'p1' {}

  -- p1 created means p0 is a class and cannot modify its metatable
  assertErrorMsgContains(msg[3], p0.set_metamethod, p0, { __tostring = tostr })

  p0 = Object 'p0' { 1, 2, z=function() return 3 end } -- fresh p0
  p0:set_metamethod { __tostring = tostr } -- clone metatable shared with Object
  assertEquals     (tostring(p0), '1, 2, z, __id, ')  -- tostring -> tostr
  assertNotEquals  (tostring(p1), '__id, ')           -- builtin tostring
  assertStrContains(tostring(p1), 'table:')           -- builtin tostring

  -- p1 still the child of old p0 and not yet a class
  p1:set_metamethod { __tostring = tostr } -- clone metatable shared with Object
  assertEquals     (tostring(p1), '__id, ')           -- tostring -> tostr

  p1 = p0 'p1' {} -- fresh p1
  assertErrorMsgContains(msg[5], p1.set_metamethod, p1, { __tostring = tostr })
  p1:set_metamethod({ __tostring = tostr }, true)  -- clone need override
  assertEquals      (tostring(p1), '__id, ')          -- tostring -> tostr
  p1:set_function({ x=function() return function() return 2 end end, y =function(s) return function(n) return s.z*n end end }) p1.z =function() return 3 end
  assertNotEquals   (tostring(p1), 'x, y, z, __id, ') -- tostring -> tostr
  assertEquals      (tostring(p1), 'y, x, __id, z, ') -- tostring -> tostr

  assertErrorMsgContains(msg[1], p0.setmm, 1)
  assertErrorMsgContains(msg[1], p0.setmm, '')
  assertErrorMsgContains(msg[1], p0.setmm, {})

  assertErrorMsgContains(msg[2], p0.setmm, p0, 1)
  assertErrorMsgContains(msg[2], p0.setmm, p0, '')

  assertErrorMsgContains(msg[4], p0.setmm, p0, {x=1})
  assertErrorMsgContains(msg[4], p0.setmm, p0, {y=''})

  assertErrorMsgContains(msg[5], p0.setmm, p0, {__index=false}, false)
end

function TestLuaObject:testGetVarKey()
  local p0 = Object 'p0' { x=1, y=2, z=function() return 3 end }
  local p1 = p0 'p1' { x=-1, y={} }
  local msg = {
    "invalid argument #1 (object expected)",
    "invalid argument #2 (object expected)",
    "invalid argument #2 (parent of argument #1 expected)",
    "invalid argument #3 (string expected)",
  }

  local t = Object:getk() assertEquals ( t, {} ) -- Object is excluded
  t = p0:getk()             table.sort(t) assertEquals (t, {'__id','x','y','z'})
  t = p0:getk(Object)       table.sort(t) assertEquals (t, {'__id','x','y','z'})
  t = p0:getk(Object.__par) table.sort(t) assertEquals (t, {'__id','x','y','z'})

  t = p1:getk()             table.sort(t) assertEquals (t, {'__id','x','y','z'})
  t = p1:getk(p0.__par)     table.sort(t) assertEquals (t, {'__id','x','y','z'})
  t = p1:getk(p0)           table.sort(t) assertEquals (t, {'__id','x','y'})
  t = p1:getk(p1.__par)     table.sort(t) assertEquals (t, {'__id','x','y'})

  t = p1:getk(p0,'^[^_]')       table.sort(t) assertEquals (t, {'x','y'})
  t = p1:getk(p0.__par,'^[^_]') table.sort(t) assertEquals (t, {'x','y','z'})
  t = p1:getk(nil,'^[^_]')      table.sort(t) assertEquals (t, {'x','y','z'})

  assertErrorMsgContains(msg[1], p0.getk, 1)
  assertErrorMsgContains(msg[1], p0.getk, 1, Object)
  assertErrorMsgContains(msg[2], p0.getk, p0, 1)
  assertErrorMsgContains(msg[3], p0.getk, p0, p1)
  assertErrorMsgContains(msg[4], p0.getk, p0, nil, 1)
end

function TestLuaObject:testStrDump()
  local p0 = Object 'p0' { x=1, y=2, z=function() return 3 end }
  local p1 = p0 'p1' { x=-1, y={} }
  local msg = {
    "invalid argument #1 (object expected)",
    "invalid argument #2 (object expected)",
    "invalid argument #2 (parent of argument #1 expected)",
    "invalid argument #3 (string expected)",
  }
  local str_p0 =[[
+ [table] 'p0'
  y:  2
  x:  1
  z:  function
]]
  local str_p1 =[[
+ [table] 'p1'
  y:  {}
  x:  -1
  + [table] 'p0'
    y:  2 (*)
    x:  1 (*)
    z:  function
]]

  assertEquals(string.gsub(p0:strdump(), ': 0x%x+', ''), str_p0)
  assertEquals(string.gsub(p1:strdump(), ': 0x%x+', ''), str_p1)

  assertErrorMsgContains(msg[1], p0.strdump, 1)
  assertErrorMsgContains(msg[1], p0.strdump, 1, Object)
  assertErrorMsgContains(msg[2], p0.strdump, p0, 1)
  assertErrorMsgContains(msg[3], p0.strdump, p0, p1)
  assertErrorMsgContains(msg[4], p0.strdump, p0, nil, 1)
end

-- examples test suite --------------------------------------------------------o

function TestLuaObject:testMetamethodForwarding()
  local msg = {
    "invalid argument #1 (forbidden access to 'ro_obj')",
    "invalid argument #2 (boolean or nil expected)",
  }

  local ro_obj = Object {} :set_readonly(true)
  local parent = ro_obj.parent
  ro_obj:set_function {
    set_readonly = function(s,f)
      assert(s ~= ro_obj, msg[1])
      return parent.set_readonly(s,f)
    end
  }
  ro_obj:set_metamethod {__init = function(s) return s:set_readonly(true) end }

  assertErrorMsgContains(msg[1], ro_obj.set_readonly, ro_obj, true)

  local ro_chld = ro_obj {}
  assertTrue ( is_readonly(ro_chld) )
  assertFalse( is_readonly(ro_chld:set_readonly(false)) )
  assertErrorMsgContains(msg[2], ro_chld.set_readonly, ro_chld, 1)
end

function TestLuaObject:testMetamethodNotification()
  local p1 = Object 'p1' { x=1, y=2  }
  local p2 = p1 'p2' { x=2, y=-1, z=0 }

  local function trace (fp, self, k, v)
--[[fp:write("object: '", self.name,
             "' is updated for key: '", tostring(k),
             "' with value: ")
    if type(v) == "string"
      then fp:write(": '", tostring(v), "'\n")
      else fp:write(":  ", tostring(v),  "\n") end
]]  end

  local function set_notification (self, file)
    local fp = file or io.stdout
    local mt = getmetatable(self)
    local nwidx = mt and rawget(mt, '__newindex')
    local mm = function (self, k, v)
      trace(fp, self, k, v) -- logging
      nwidx(    self, k, v) -- forward
    end
    self:set_metamethod({__newindex=mm}, true) -- override!
  end

  set_notification(p2) -- new metamethod created, metatable is cloned
  p2.x = 3 -- new behavior, notify about update

  local p3 = p2 'p3' { x=3  } -- new, inherit metatable
  p3.x = 4 -- new behavior, notify about update

  local p4 = p2 'p4' { x=4 } -- new, inherit metatable
  p4.x = 5 -- new behavior, notify about update
end

function TestLuaObject:testMetamethodCounting()
  local count = 0
  local set_counter = function(s) return s:setmm { __init =function() count=count+1 end } end

  local o0 = Object 'o0' {}          set_counter(o0)
  local o1 = o0 'o1' { a = 2 }       assertEquals( count, 1 )
  local o2 = o1 'o2' { a = 2 }       assertEquals( count, 2 )
  local a = Object 'a' { x = o2.a }  assertEquals( count, 2 )
end

-- performance test suite -----------------------------------------------------o

Test_LuaObject = {}

function Test_LuaObject:testPrimes()
  local Primes = Object {}

  Primes:set_function {
    isPrimeDivisible = function(s,c)
      for i=3, s.prime_count do
        if s.primes[i] * s.primes[i] > c then break end
        if c % s.primes[i] == 0 then return true end
      end
      return false
    end,

    addPrime = function(s,c)
      s.prime_count = s.prime_count + 1
      s.primes[s.prime_count] = c
    end,

    getPrimes = function(s,n)
      s.prime_count, s.primes = 3, { 1,2,3 }
      local c = 5
      while s.prime_count < n do
        if not s:isPrimeDivisible(c) then
          s:addPrime(c)
        end
        c = c + 2
      end
    end
  }

  local p = Primes {}
  local t0 = os.clock()
  p:getPrimes(2e5)
  local dt = os.clock() - t0
  assertEquals( p.primes[p.prime_count], 2750131 )
  assertAlmostEquals( dt , 0.5, 1 )
end

function Test_LuaObject:testDuplicates()
  local DupFinder = Object {}

  DupFinder:set_function {
    find_duplicates = function(s,res)
      for _,v in ipairs(s) do
        res[v] = res[v] and res[v]+1 or 1
      end
      for _,v in ipairs(s) do
        if res[v] and res[v] > 1 then
          res[#res+1] = v
        end
        res[v] = nil
      end
    end,

    clear = function(s)
      for i=1,#s do s[i]=nil end
      return s
    end
  }

  local inp = DupFinder {'b','a','c','c','e','a','c','d','c','d'}
  local out = DupFinder {'a','c','d'}
  local res = DupFinder {}

  local t0 = os.clock()
  for i=1,5e5 do inp:find_duplicates(res:clear()) end
  local dt = os.clock() - t0
  assertEquals( res, out )
  assertAlmostEquals( dt , 0.5, 1 )
end

function Test_LuaObject:testLinkedList()
  local List = Object {}
  local nxt = {}

  local function generate(n)
    local t = List {x=1}
    for j=1,n do t = List {[nxt]=t} end
    return t
  end

  local function find(t,k)
    if t[k] ~= nil then return t[k] end
    return find(t[nxt],k)
  end

  local l, s, n = generate(10), 0, 1e6
  local t0 = os.clock()
  for i=1,n do s = s + find(l, 'x') end
  local dt = os.clock() - t0
  assertEquals( s, n )
  assertAlmostEquals( dt, 0.5, 1 )
end

-- end ------------------------------------------------------------------------o

-- run as a standalone test with luajit
if MAD == nil then
  os.exit( lu.LuaUnit.run() )
end
