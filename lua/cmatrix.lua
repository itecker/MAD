local M = { __author = 'ldeniau', __version = '2015.06', __help = {}, __test = {} }

-- MAD -------------------------------------------------------------------------

M.__help.self = [[
NAME
  cmatrix

SYNOPSIS
  local cmatrix = require 'cmatrix'
  local m1 = cmatrix {{1,2+2i},{3,4+2i},{5,6+2i}}
  local m2 = cmatrix(2,3)
  local m3 = m1:transpose()
  m1:transpose(m2) 

DESCRIPTION
  The module cmatrix implements the operators and math functions on
  complex matrices:
    (minus) -, +, -, *, /, %, ^, ==,
    rows, cols, size, sizes, get, set, zeros, ones,
    unm, add, sub, mul, div, mod, pow, schur_prod,
    get_row, get_col, get_diag, transpose,
    set_row, set_col, set_diag, set_table,
    real, imag, conj, trace, norm, angle, inner_prod,
    abs, arg, exp, log, pow, sqrt, proj,
    sin, cos, tan, sinh, cosh, tanh,
    asin, acos, atan, asinh, acosh, atanh,
    copy, foldl, foldr, map, map2, tostring, totable.

RETURN VALUES
  The constructor of complex matrices

SEE ALSO
  math, gmath, complex, vector, cvector, matrix
]]
 
-- DEFS ------------------------------------------------------------------------

local ffi    = require 'ffi'
local linalg = require 'linalg'
local gm     = require 'gmath'

-- locals
local clib            = linalg.cmad
local vector, cvector = linalg.vector, linalg.cvector
local matrix, cmatrix = linalg.matrix, linalg.cmatrix

local isnum, iscpx, iscalar, isvec, iscvec, ismat, iscmat,
      real, imag, conj, ident, min,
      abs, arg, exp, log, sqrt, proj,
      sin, cos, tan, sinh, cosh, tanh,
      asin, acos, atan, asinh, acosh, atanh,
      unm, mod, pow = 
      gm.is_number, gm.is_complex, gm.is_scalar,
      gm.is_vector, gm.is_cvector, gm.is_matrix, gm.is_cmatrix,
      gm.real, gm.imag, gm.conj, gm.ident, gm.min,
      gm.abs, gm.arg, gm.exp, gm.log, gm.sqrt, gm.proj,
      gm.sin, gm.cos, gm.tan, gm.sinh, gm.cosh, gm.tanh,
      gm.asin, gm.acos, gm.atan, gm.asinh, gm.acosh, gm.atanh,
      gm.unm, gm.mod, gm.pow

local istype, sizeof, fill = ffi.istype, ffi.sizeof, ffi.fill

local cres = ffi.new 'complex[1]'

-- Lua API

local function idx (x, i, j)
  return (i-1) * x.nc + (j-1)
end

function M.rows  (x)          return x.nr        end
function M.cols  (x)          return x.nc        end
function M.size  (x)          return x.nr * x.nc end
function M.sizes (x)          return x.nr , x.nc end
function M.get   (x, i, j)    return x.data[idx(x,i,j)] end
function M.set   (x, i, j, e) x.data[idx(x,i,j)] = e ; return x end

function M.zeros (x)
  fill(x.data, sizeof('complex', x:size()))
  return x
end

function M.ones (x, e_)
  x:zeros()
  local n, e = min(x:sizes()), e_ or 1
  for i=1,n do x:set(i,i, e) end
  return x
end

function M.get_col (x, jc, r_)
  local nr = x:rows()
  local r = r_ or vector(nr)
  assert(nr == #r, "incompatible cmatrix-cvector sizes")
  for i=1,nr do r[i] = x:get(i,jc) end
  return r
end

function M.get_row (x, ir, r_)
  local nc = x:cols()
  local r = r_ or vector(nc)
  assert(nc == #r, "incompatible cmatrix-cvector sizes")
  for i=1,nc do r[i] = x:get(i,ir) end
  return r
end

function M.get_diag (x, r_)
  local n = min(x:sizes())
  local r = r_ or vector(n)
  assert(n == #r, "incompatible cmatrix-cvector sizes")
  for i=1,n do r[i] = x:get(i,i) end
  return r
end

function M.set_col (x, jc, v)
  local nr = x:rows()
  assert(nr == #v, "incompatible cmatrix-cvector sizes")
  for i=1,nr do x:set(i,jc, v[i]) end
  return x
end

function M.set_row (x, ir, v)
  local nc = x:cols()
  assert(nc == #v, "incompatible cmatrix-cvector sizes")
  for j=1,nc do x:set(ir,j, v[i]) end
  return x
end

function M.set_diag (x, v)
  local n = min(x:sizes())
  assert(n == #v, "incompatible cmatrix-cvector sizes")
  for i=1,n do x:set(i,i, v[i]) end
  return x
end

function M.set_table (x, tbl)
  local nr, nc = x:sizes()
  assert(#tbl == nr, "incompatible cmatrix col sizes with table of tables")
  for i=1,nr do
    local ti, xi = tbl[i], idx(x,i,0)
    assert(#ti == nc, "incompatible cmatrix row sizes with table of tables")
    for j=1,nc do x.data[xi + j] = ti[j] end
  end
  return x
end

function M.foldl (x, r, f)
  local nr, nc = x:sizes()
  assert(nr == #r, "incompatible cmatrix-cvector sizes")
  for i=1,nr do
    local ri, xi = r[i], idx(x,i,0)
    for j=1,nc do ri = f(ri, x.data[xi+j]) end
    r[i] = ri
  end
  return r
end

function M.foldr (x, r, f)
  local nr, nc = x:sizes()
  assert(nr == #r, "incompatible cmatrix-cvector sizes")
  for i=1,nr do
    local ri, xi = r[i], idx(x,i,0)
    for j=1,nc do ri = f(x.data[xi+j], ri) end
    r[i] = ri
  end
  return r
end

function M.map (x, f, r_)
  local nr, nc = x:sizes()
  local r = r_ or cmatrix(nr, nc)
  assert(nr == r:rows() and nc == r:cols(), "incompatible cmatrix sizes")
  for i=0,nr*nc-1 do r.data[i] = f(x.data[i]) end
  return r
end

function M.map2 (x, y, f, r_)
  local nr, nc = x:sizes()
  local r = r_ or cmatrix(nr, nc)
  assert(nr == y:rows() and nc == y:cols(), "incompatible cmatrix sizes")
  assert(nr == r:rows() and nc == r:cols(), "incompatible cmatrix sizes")
  for i=0,nr*nc-1 do r.data[i] = f(x.data[i], y.data[i]) end
  return r
end

function M.schur_prod (x, y, r_)
  local nr, nc = x:sizes()
  local r = r_ or cmatrix(nr, nc)
  assert(nr == y:rows() and nc == y:cols(), "incompatible cmatrix sizes")
  assert(nr == r:rows() and nc == r:cols(), "incompatible cmatrix sizes")
  if ismat(y) then
    clib.mad_cvec_mulv(x.data, y.data, r.data, nr*nc)
  else
    clib.mad_cvec_mul (x.data, y.data, r.data, nr*nc)
  end
  return r
end

function M.transpose (x, r_)
  local nr, nc = x:sizes()
  local r = r_ or cmatrix(nc, nr)
  assert(nr == r:rows() and nc == r:cols(), "incompatible cmatrix sizes")
  clib.mad_cmat_trans(x.data, r.data, nr, nc)
  return r
end

function M.trace (x)
  local n = min(x:sizes())
  local r = 0
  for i=1,n do r = r + x:get(i,i) end
  return r
end

function M.inner_prod (x, y)
  return (x:transpose() * y):trace()
end

function M.norm (x)
  -- Frobenius (consistent with inner_prod)
  clib.mad_cvec_dot(x.data, x.data, cres, x:size())
  return sqrt(cres[0])
end

function M.angle (x, y)
  local w = x:inner_prod(y)
  local v = x:norm() * y:norm()
  return acos(w / v) -- [0, pi]
end

function M.copy  (x, r_)  return x:map(ident, r_) end
function M.real  (x, r_)  return x:map(real , r_) end
function M.imag  (x, r_)  return x:map(imag , r_) end
function M.conj  (x, r_)  return x:map(conj , r_) end
function M.abs   (x, r_)  return x:map(abs  , r_) end
function M.arg   (x, r_)  return x:map(arg  , r_) end
function M.exp   (x, r_)  return x:map(exp  , r_) end
function M.log   (x, r_)  return x:map(log  , r_) end
function M.sqrt  (x, r_)  return x:map(sqrt , r_) end
function M.proj  (x, r_)  return x:map(proj , r_) end
function M.sin   (x, r_)  return x:map(sin  , r_) end
function M.cos   (x, r_)  return x:map(cos  , r_) end
function M.tan   (x, r_)  return x:map(tan  , r_) end
function M.sinh  (x, r_)  return x:map(sinh , r_) end
function M.cosh  (x, r_)  return x:map(cosh , r_) end
function M.tanh  (x, r_)  return x:map(tanh , r_) end
function M.asin  (x, r_)  return x:map(asin , r_) end
function M.acos  (x, r_)  return x:map(acos , r_) end
function M.atan  (x, r_)  return x:map(atan , r_) end
function M.asinh (x, r_)  return x:map(asinh, r_) end
function M.acosh (x, r_)  return x:map(acosh, r_) end
function M.atanh (x, r_)  return x:map(atanh, r_) end
function M.unm   (x, r_)  return x:map(unm  , r_) end
function M.mod   (x, y, r_) return x:map2(y, mod, r_) end -- TODO
function M.pow   (x, y, r_) return x:map2(y, pow, r_) end -- TODO

function M.__eq (x, y)
  if iscalar(y) then
    for i=0,x:size()-1 do
      if x.data[i] ~= y then return false end
    end
    return true
  end

  if x:rows() ~= y:rows() or x:cols() ~= y:cols() then return false end
  for i=0,x:size()-1 do
    if x.data[i] ~= y.data[i] then return false end
  end
  return true
end

function M.add (x, y, r_)
  if isnum(x) then -- num + cmat => cvec + num
    local r = r_ or cmatrix(y:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(y:rows() == r:rows() and y:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_addn (y.data, x, r.data, r:size())
    return r
  end

  -- iscmat(x)
  local r
  if isnum(y) then -- cmat + num => cvec + num
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_vec_addn(x.data, y, r.data, r:size())
  elseif iscpx(y) then -- cmat + cpx => cvec + cpx
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_vec_addc(x.data, y.re, y.im, r.data, r:size())
  elseif ismat(y) then -- cmat + mat => cvec + vec
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == y:rows() and x:cols() == y:cols(), "incompatible cmatrix sizes")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_vec_add(x.data, y.data, r.data, r:size())
  elseif iscmat(y) then -- cmat + cmat => cvec + cvec
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == y:rows() and x:cols() == y:cols(), "incompatible cmatrix sizes")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_addv(y.data, x.data, r.data, r:size())
  else
    error("incompatible cmatrix (+) operands")
  end
  return r
end

function M.sub (x, y, r_)
  if isnum(x) then -- num - cmat => num - cvec
    local r = r_ or cmatrix(y:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(y:rows() == r:rows() and y:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_subn (y.data, x, r.data, r:size())
    return r
  end

  -- iscmat(x)
  local r
  if isnum(y) then -- cmat - num => cvec + -num
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_addn(x.data, -y, r.data, r:size())
  elseif iscpx(y) then -- cmat - cpx => cvec + -cpx
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_addc(x.data, -y.re, -y.im, r.data, r:size())
  elseif ismat(y) then -- cmat - mat => cvec - vec
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == y:rows() and x:cols() == y:cols(), "incompatible cmatrix sizes")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_subv(x.data, y.data, r.data, r:size())
  elseif iscmat(y) then -- cmat - cmat => cvec - cvec
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == y:rows() and x:cols() == y:cols(), "incompatible cmatrix sizes")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_sub(x.data, y.data, r.data, r:size())
  else
    error("incompatible cmatrix (-) operands")
  end
  return r
end

function M.mul (x, y, r_)
  if isnum(x) then -- num * cmat => cvec * num
    local r = r_ or cmatrix(y:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(y:rows() == r:rows() and y:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_muln (y.data, x, r.data, r:size())
    return r
  end

  -- iscmat(x)
  local r
  if isnum(y) then -- cmat * num => cvec * num
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_muln(x.data, y, r.data, r:size())
  elseif iscpx(y) then -- cmat * cpx => cvec * cpx
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_mulc(x.data, y.re, y.im, r.data, r:size())
  elseif isvec(y) then -- cmat * vec
    r = r_ or cvector(x:rows())
    assert(iscvec(r), "incompatible cmatrix-cvector kinds")
    assert(x:cols() == y:size(),                  "incompatible cmatrix-vector sizes")
    assert(x:rows() == r:size(),                  "incompatible cmatrix-vector sizes")
    clib.mad_cmat_mulv(x.data, y.data, r.data, x:rows(), x:cols())
  elseif iscvec(y) then -- cmat * cvec
    r = r_ or cvector(x:rows())
    assert(iscvec(r), "incompatible cmatrix-cvector kinds")
    assert(x:cols() == y:size(),                  "incompatible cmatrix-cvector sizes")
    assert(x:rows() == r:size(),                  "incompatible cmatrix-cvector sizes")
    clib.mad_cmat_mulc(x.data, y.data, r.data, x:rows(), x:cols())
  elseif ismat(y) then -- cmat * mat
    r = r_ or cmatrix(x:rows(), y:cols())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:cols() == y:rows(),                          "incompatible cmatrix sizes")
    assert(x:rows() == r:rows() and y:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cmat_mulm(x.data, y.data, r.data, r:rows(), r:cols(), x:cols())
  elseif iscmat(y) then -- cmat * cmat
    r = r_ or cmatrix(x:rows(), y:cols())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:cols() == y:rows(),                          "incompatible cmatrix sizes")
    assert(x:rows() == r:rows() and y:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cmat_mul(x.data, y.data, r.data, r:rows(), r:cols(), x:cols())
  else
    error("incompatible cmatrix (*) operands")
  end
  return r
end

function M.div (x, y, r_)
  if isnum(x) then -- num / cmat => num * inv(cmat)
    error("num/cmat: NYI cmatrix inverse")
  end

  -- iscmat(x)
  local r
  if isnum(y) then -- cmat / num => cvec * (1/num)
    r = r_ or cmatrix(x:sizes())
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_muln(x.data, 1/y, r.data, r:size())
  elseif iscpx(y) then -- cmat / cpx => cvec * (1/cpx)
    r, y = r_ or cmatrix(x:sizes()), 1/y
    assert(iscmat(r), "incompatible cmatrix kinds")
    assert(x:rows() == r:rows() and x:cols() == r:cols(), "incompatible cmatrix sizes")
    clib.mad_cvec_mulc(x.data, y.re, y.im, r.data, r:size())
  elseif ismat(y) then -- cmat / mat => cmat * inv(mat)
    error("cmat/mat: NYI matrix inverse")
  elseif iscmat(y) then -- cmat / cmat => cmat * inv(cmat)
    error("cmat/cmat: NYI cmatrix inverse")
  else
    error("incompatible cmatrix (/) operands")
  end
  return r
end

function M.tostring (x, sep_, lsep_)
  local nr, nc = x:sizes()
  local r, c = {}, {}
  for i=1,nr do
    for j=1,nc do c[j] = tostring(x:get(i,j)) end
    r[i] = table.concat(c, sep_ or ' ')
  end
  return table.concat(r, lsep_ or '\n')
end

local tbl_new = require 'table.new'

function M.totable(x, r_)
  local nr, nc = x:sizes()
  local r = r_ or tbl_new(nr,0)
  assert(type(r) == 'table', "invalid argument, table expected")
  for i=1,nr do
    local c = r[i] or tbl_new(nc,0)
    assert(type(c) == 'table', "invalid argument, table of tables expected")
    for j=1,nc do c[j] = x:get(i,j) end
    r[i] = c
  end
  return r
end

M.__unm      = M.unm
M.__add      = M.add
M.__sub      = M.sub
M.__mul      = M.mul
M.__div      = M.div
M.__mod      = M.mod
M.__pow      = M.pow
M.__tostring = M.tostring
M.__index  = M

ffi.metatype('cmatrix_t', M)

-- END -------------------------------------------------------------------------
return cmatrix