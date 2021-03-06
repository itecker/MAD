/*
 o----------------------------------------------------------------------------o
 |
 | TPSA functions module implementation
 |
 | Methodical Accelerator Design - Copyright CERN 2016+
 | Support: http://cern.ch/mad  - mad at cern.ch
 | Authors: L. Deniau, laurent.deniau at cern.ch
 |          C. Tomoiaga
 | Contrib: -
 |
 o----------------------------------------------------------------------------o
 | You can redistribute this file and/or modify it under the terms of the GNU
 | General Public License GPLv3 (or later), as published by the Free Software
 | Foundation. This file is distributed in the hope that it will be useful, but
 | WITHOUT ANY WARRANTY OF ANY KIND. See http://gnu.org/licenses for details.
 o----------------------------------------------------------------------------o
*/

#include <math.h>
#include <assert.h>

#include "mad_cst.h"
#include "mad_log.h"
#include "mad_desc_impl.h"

#ifdef    MAD_CTPSA_IMPL
#include "mad_ctpsa_impl.h"
#else
#include "mad_tpsa_impl.h"
#endif

// TODO: check domain of validity! (input values)
// TODO: taylor series differs for complex series...
// TODO: use complex series to expand obove order 5

// --- LOCAL FUNCTIONS --------------------------------------------------------

static inline void
fixed_point_iteration(const T *a, T *c, int iter, NUM expansion_coef[iter+1])
{
  assert(a && c && expansion_coef);
  assert(iter >= 1); // ord 0 treated outside

  T *acp = a->d->PFX(t[2]);
  if (iter >=2)      // save copy before scale, to deal with aliasing
    FUN(copy)(a,acp);

  // iter 1
  FUN(scl)(a, expansion_coef[1], c);
  FUN(set0)(c, 0, expansion_coef[0]);

  // iter 2..iter
  if (iter >= 2) {
    T *pow = a->d->PFX(t[1]),
      *tmp = a->d->PFX(t[3]), *t;
    FUN(set0)(acp, 0,0);
    FUN(copy)(acp,pow);  // already did ord 1

    for (int i = 2; i <= iter; ++i) {
      FUN(mul)(acp,pow,tmp);
      FUN(acc)(tmp,expansion_coef[i],c);
      SWAP(pow,tmp,t);
    }
  }
}

static inline void
sincos_fixed_point(const T *a, T *s, T *c, int iter_s, NUM sin_coef[iter_s+1], int iter_c, NUM cos_coef[iter_c+1])
{
  assert(a && s && c && sin_coef && cos_coef);
  assert(iter_s >= 1 && iter_c >= 1);  // ord 0 treated outside

  int max_iter = MAX(iter_s,iter_c);
  T *acp = a->d->PFX(t[2]);
  if (max_iter >= 2)      // save copy before scale, to deal with aliasing
    FUN(copy)(a,acp);

  // iter 1
  FUN(scl)(a,sin_coef[1],s); FUN(set0)(s, 0,sin_coef[0]);
  FUN(scl)(a,cos_coef[1],c); FUN(set0)(c, 0,cos_coef[0]);

  if (max_iter >= 2) {
    T *pow = a->d->PFX(t[1]),
      *tmp = a->d->PFX(t[3]), *t;
    FUN(set0)(acp, 0,0);
    FUN(copy)(acp,pow);

    for (int i = 1; i <= max_iter; ++i) {
      FUN(mul)(acp,pow,tmp);

      if (i <= iter_s) FUN(acc)(tmp,sin_coef[i],s);
      if (i <= iter_c) FUN(acc)(tmp,cos_coef[i],c);
      SWAP(pow,tmp,t);
    }
  }
}

// --- PUBLIC FUNCTIONS -------------------------------------------------------

#ifdef MAD_CTPSA_IMPL

void FUN(inv_r) (const T *a, num_t v_re, num_t v_im, T *c)
{ FUN(inv)(a, CNUM(v), c); }

void FUN(invsqrt_r) (const T *a, num_t v_re, num_t v_im, T *c)
{ FUN(invsqrt)(a, CNUM(v), c); }

#endif

void
FUN(inv) (const T *a, NUM v, T *c) // v/a
{
  assert(a && c);
  ensure(a->d == c->d);
  ensure(a->coef[0] != 0);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, v/a->coef[0]); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] = 1 / a0;
  for (int o = 1; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-1] / a0;
  fixed_point_iteration(a,c,to,expansion_coef);
  FUN(scl)(c,v,c);
}

void
FUN(sqrt) (const T *a, T *c)
{
// SQRT(A0+P) = SQRT(A0)*(1+1/2(P/A0)-1/8*(P/A0)**2+...)
  assert(a && c);
  ensure(a->d == c->d);
  SELECT(ensure(a->coef[0] >= 0),);

  if (a->coef[0] == 0) { FUN(clear)(c); return; }

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, sqrt(a->coef[0])); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] = sqrt(a0);
  for (int o = 1; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-1] / a0 / (2*o) * (2*o-3);

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(invsqrt) (const T *a, NUM v, T *c)  // v/sqrt(a)
{
  assert(a && c);
  ensure(a->d == c->d);
  ensure(a->coef[0] SELECT(> 0, != 0));

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, v/sqrt(a->coef[0])); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] = 1/sqrt(a0);
  for (int o = 1; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-1] / a0 / (2*o) * (2*o-1);

  fixed_point_iteration(a,c,to,expansion_coef);
  FUN(scl)(c,v,c);
}

void
FUN(exp) (const T *a, T *c)
{
// EXP(A0+P) = EXP(A0)*(1+P+P**2/2!+...)
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, exp(a->coef[0])); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] = exp(a0);
  for (int o = 1; o <= to; ++o)
    expansion_coef[o] = expansion_coef[o-1] / o;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(log) (const T *a, T *c)
{
// LOG(A0+P) = LOG(A0) + (P/A0) - 1/2*(P/A0)**2 + 1/3*(P/A0)**3 - ...)
  assert(a && c);
  ensure(a->d == c->d);
  ensure(a->coef[0] SELECT(> 0, != 0));

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, log(a->coef[0])); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] = log(a0);
  expansion_coef[1] = 1/a0;
  for (int o = 2; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-1] / a0 / o * (o-1);

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(sin) (const T *a, T *c)
{
// SIN(A0+P) = SIN(A0)*(1-P**2/2!+P**4/4!+...) + COS(A0)*(P-P**3/3!+P**5/5!+...)
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, sin(a->coef[0])); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] = sin(a0);
  expansion_coef[1] = cos(a0);
  for (int o = 2; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-2] / (o*(o-1));

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(cos) (const T *a, T *c)
{
// COS(A0+P) = COS(A0)*(1-P**2/2!+P**4/4!+...) - SIN(A0)*(P-P**3/3!+P**5/5!+...)
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, cos(a->coef[0])); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] =  cos(a0);
  expansion_coef[1] = -sin(a0);
  for (int o = 2; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-2] / (o*(o-1));

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(sincos) (const T *a, T *s, T *c)
{
  assert(a && s && c);
  ensure(a->d == s->d && a->d == c->d);

  ord_t sto = MIN(s->mo,s->d->trunc),
        cto = MIN(c->mo,c->d->trunc);

  NUM s_a0 = sin(a->coef[0]), c_a0 = cos(a->coef[0]);
  if (a->hi == 0) {
    FUN(scalar)(s, s_a0);
    FUN(scalar)(c, c_a0);
    return;
  }
  if (!sto || !cto) {
    if (!sto) FUN(scalar)(s, s_a0);
    else      FUN(sin)(a,s);
    if (!cto) FUN(scalar)(c, c_a0);
    else      FUN(cos)(a,c);
    return;
  }

  // ord 0, 1
  NUM sin_coef[sto+1], cos_coef[cto+1];
  sin_coef[0] = s_a0;  cos_coef[0] =  c_a0;
  sin_coef[1] = c_a0;  cos_coef[1] = -s_a0;

  // ords 2..to
  for (int o = 2; o <= sto; ++o )
    sin_coef[o] = -sin_coef[o-2] / (o*(o-1));
  for (int o = 2; o <= cto; ++o )
    cos_coef[o] = -cos_coef[o-2] / (o*(o-1));

  sincos_fixed_point(a,s,c, sto,sin_coef, cto,cos_coef);
}

void
FUN(sinh) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, sinh(a->coef[0])); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] = sinh(a0);
  expansion_coef[1] = cosh(a0);
  for (int o = 2; o <= to; ++o)
    expansion_coef[o] = expansion_coef[o-2] / (o*(o-1));

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(cosh) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to || a->hi == 0) { FUN(scalar)(c, cosh(a->coef[0])); return; }

  NUM expansion_coef[to+1], a0 = a->coef[0];
  expansion_coef[0] = cosh(a0);
  expansion_coef[1] = sinh(a0);
  for (int o = 2; o <= to; ++o)
    expansion_coef[o] = expansion_coef[o-2] / (o*(o-1));

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(sincosh) (const T *a, T *sh, T *ch)
{
  assert(a && sh && ch);
  ensure(a->d == sh->d && a->d == ch->d);

  ord_t sto = MIN(sh->mo,sh->d->trunc),
        cto = MIN(ch->mo,ch->d->trunc);

  NUM s_a0 = sinh(a->coef[0]), c_a0 = cosh(a->coef[0]);  // TODO: use sincos ?
  if (a->hi == 0) {
    FUN(scalar)(sh, s_a0);
    FUN(scalar)(ch, c_a0);
    return;
  }
  if (!sto || !cto) {
    if (!sto) FUN(scalar)(sh, s_a0);
    else      FUN(sinh)(a,sh);
    if (!cto) FUN(scalar)(ch, c_a0);
    else      FUN(cos)(a,ch);
    return;
  }

  // ord 0, 1
  NUM sin_coef[sto+1], cos_coef[cto+1];
  sin_coef[0] = s_a0;  cos_coef[0] = c_a0;
  sin_coef[1] = c_a0;  cos_coef[1] = s_a0;

  // ords 2..to
  for (int o = 2; o <= sto; ++o )
    sin_coef[o] = sin_coef[o-2] / (o*(o-1));
  for (int o = 2; o <= cto; ++o )
    cos_coef[o] = cos_coef[o-2] / (o*(o-1));

  sincos_fixed_point(a,sh,ch, sto,sin_coef, cto,cos_coef);
}

void
FUN(sirx) (const T *a, T *c)
{
// SIN(SQRT(P))/SQRT(P) = 1 - P/3! + P**2/5! - P**3/7! + ...
  assert(a && c);
  ensure(a->d == c->d);
  ensure(a->coef[0] == 0);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to) { FUN(scalar)(c, 1); return; }

  NUM expansion_coef[to+1];
  expansion_coef[0] = 1;
  for (int o = 1; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-1] / (2*o * (2*o+1));

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(corx) (const T *a, T *c)
{
// COS(SQRT(P)) = 1 - P/2! + P**2/4! - P**3/6! + ...
  assert(a && c);
  ensure(a->d == c->d);
  ensure(a->coef[0] == 0);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to) { FUN(scalar)(c, 1); return; }

  NUM expansion_coef[to+1];
  expansion_coef[0] = 1;
  for (int o = 1; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-1] / (2*o * (2*o-1));

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(sinc) (const T *a, T *c)
{
// SIN(P)/P = 1 - P**2/3! + P**4/5! - P**6/7! + ...
  assert(a && c);
  ensure(a->d == c->d);
  ensure(a->coef[0] == 0);

  ord_t to = MIN(c->mo,c->d->trunc);
  if (!to) { FUN(scalar)(c, 1); return; }

  NUM expansion_coef[to+1];
  expansion_coef[0] = 1;
  expansion_coef[1] = 0;
  for (int o = 2; o <= to; ++o)
    expansion_coef[o] = -expansion_coef[o-2] / (o * (o+1));

  fixed_point_iteration(a,c,to,expansion_coef);
}

// --- The following functions are manually expanded up to order 5

enum { MANUAL_EXPANSION_ORD = 5 };

void
FUN(tan) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);

  if (!to || a->hi == 0) { FUN(scalar)(c, tan(a->coef[0])); return; }
  if (to > 5) {
    FUN(cos)(a,c);
    FUN(inv)(c,1,c);
    T *tmp = c->d->PFX(t[4]);
    FUN(sin)(a,tmp);
    FUN(mul)(tmp,c,c);  // 1 copy
    return;
  }

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  NUM sa = sin(a0), ca = cos(a0);
  ensure(ca != 0);

  NUM          xcf1 = 1/ca;
  expansion_coef[0] = sa                     *xcf1;
  expansion_coef[1] = 1                      *xcf1*xcf1;
  expansion_coef[2] = sa                     *xcf1*xcf1*xcf1;
  expansion_coef[3] = (  ca*ca + 3*sa*sa)    *xcf1*xcf1*xcf1*xcf1 /3;
  expansion_coef[4] = (2*sa    +   sa*sa*sa) *xcf1*xcf1*xcf1*xcf1*xcf1 /3;
  expansion_coef[5] = (2*ca*ca + 3*ca*ca*sa*sa + 10*sa*sa + 5*sa*sa*sa*sa)
                                              *xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 /15;
  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(cot) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);

  if (!to || a->hi == 0) { FUN(scalar)(c, tan(M_PI_2 - a->coef[0])); return; }
  if (to > 5) {
    FUN(sin)(a,c);
    FUN(inv)(c,1,c);
    T *tmp = c->d->PFX(t[4]);
    FUN(cos)(a,tmp);
    FUN(mul)(tmp,c,c);  // 1 copy
    return;
  }

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  NUM sa = sin(a0), ca = cos(a0);
  ensure(sa != 0);

  NUM          xcf1 = 1/sa;
  expansion_coef[0] = ca                  *xcf1;
  expansion_coef[1] = -1                  *xcf1*xcf1;
  expansion_coef[2] = ca                  *xcf1*xcf1*xcf1;
  expansion_coef[3] = -(sa*sa +  3*ca*ca) *xcf1*xcf1*xcf1*xcf1 /3;
  expansion_coef[4] =  (2*ca  + ca*ca*ca) *xcf1*xcf1*xcf1*xcf1*xcf1 /3;
  expansion_coef[5] = -(2*sa*sa + 3*sa*sa*ca*ca + 10*ca*ca + 5*ca*ca*ca*ca)
                                          *xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 /15;
  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(asin) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  ensure(SELECT(fabs(a0) < 1, a0*a0 != 1));

  NUM          xcf1 = 1 / sqrt(1 - a0*a0);
  expansion_coef[0] = asin(a0);
  expansion_coef[1] =                        xcf1;
  expansion_coef[2] =            a0        * xcf1*xcf1*xcf1                     / 2;
  expansion_coef[3] = (1    +  2*a0*a0   ) * xcf1*xcf1*xcf1*xcf1*xcf1           / 6;
  expansion_coef[4] = (3*a0 +  2*a0*a0*a0) * xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 / 8;
  expansion_coef[5] = (3    + 24*a0*a0 + 8*a0*a0*a0*a0)
                      *            xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 / 40;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(acos) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  ensure(SELECT(fabs(a0) < 1, a0*a0 != 1));

  NUM          xcf1 = 1 / sqrt(1 - a0*a0);
  expansion_coef[0] = acos(a0);
  expansion_coef[1] = -                       xcf1;
  expansion_coef[2] = -           a0        * xcf1*xcf1*xcf1                     / 2;
  expansion_coef[3] = -(1    +  2*a0*a0   ) * xcf1*xcf1*xcf1*xcf1*xcf1           / 6;
  expansion_coef[4] = -(3*a0 +  2*a0*a0*a0) * xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 / 8;
  expansion_coef[5] = -(3    + 24*a0*a0 + 8*a0*a0*a0*a0)
                      *             xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 / 40;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(atan) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  ensure(a0*a0 != -1);

  NUM          xcf1 = 1 / (1 +  a0*a0);
  expansion_coef[0] = atan(a0);
  expansion_coef[1] =                                    xcf1;
  expansion_coef[2] = -a0                              * xcf1*xcf1;
  expansion_coef[3] = -(1.0/3 - a0*a0)                 * xcf1*xcf1*xcf1;
  expansion_coef[4] =  (a0    - a0*a0*a0)              * xcf1*xcf1*xcf1*xcf1;
  expansion_coef[5] =  (1.0/5 + a0*a0*a0*a0 - 2*a0*a0) * xcf1*xcf1*xcf1*xcf1*xcf1;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(acot) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  ensure(a0*a0 != -1);

  NUM          xcf1 = 1 / (1 + a0*a0);
  expansion_coef[0] = 2*atan(1) - atan(a0);
  expansion_coef[1] = -                                  xcf1;
  expansion_coef[2] =           a0                     * xcf1*xcf1;
  expansion_coef[3] =  (1.0/3 - a0*a0)                 * xcf1*xcf1*xcf1;
  expansion_coef[4] = -(a0    - a0*a0*a0)              * xcf1*xcf1*xcf1*xcf1;
  expansion_coef[5] = -(1.0/5 + a0*a0*a0*a0 - 2*a0*a0) * xcf1*xcf1*xcf1*xcf1*xcf1;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(tanh) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  NUM sa = sinh(a0), ca = cosh(a0);
  ensure(ca != 0);

  NUM          xcf1 = 1/ca;
  expansion_coef[0] = sa                  *xcf1;
  expansion_coef[1] =  1                  *xcf1*xcf1;
  expansion_coef[2] = -sa                 *xcf1*xcf1*xcf1;
  expansion_coef[3] = (-ca*ca +  3*sa*sa) *xcf1*xcf1*xcf1*xcf1 /3;
  expansion_coef[4] = (2*sa   - sa*sa*sa) *xcf1*xcf1*xcf1*xcf1*xcf1 /3;
  expansion_coef[5] = (2*ca*ca - 3*ca*ca*sa*sa - 10*sa*sa + 5*sa*sa*sa*sa)
                                          *xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 /15;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(coth) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  NUM sa = sinh(a0), ca = cosh(a0);
  ensure(sa != 0);

  NUM          xcf1 = 1/sa;
  expansion_coef[0] = ca                      *xcf1;
  expansion_coef[1] = -1                      *xcf1*xcf1;
  expansion_coef[2] = ca                      *xcf1*xcf1*xcf1;
  expansion_coef[3] = (sa*sa    - 3*ca*ca)    *xcf1*xcf1*xcf1*xcf1 /3;
  expansion_coef[4] = ( 2*ca    +   ca*ca*ca) *xcf1*xcf1*xcf1*xcf1*xcf1 /3;
  expansion_coef[5] = ( 2*sa*sa + 3*sa*sa*ca*ca - 10*ca*ca - 5*ca*ca*ca*ca)
                                              *xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 /15;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(asinh) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  ensure(a0*a0 != -1);

  expansion_coef[0] = asinh(a0);
  NUM          xcf1 = 1 / sqrt(1 + a0*a0);
  expansion_coef[1] =                        xcf1;
  expansion_coef[2] = -          a0        * xcf1*xcf1*xcf1                     / 2;
  expansion_coef[3] = (-1   +  2*a0*a0   ) * xcf1*xcf1*xcf1*xcf1*xcf1           / 6;
  expansion_coef[4] = (3*a0 -  2*a0*a0*a0) * xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 / 8;
  expansion_coef[5] = (3    - 24*a0*a0 + 8*a0*a0*a0*a0)
                      *           xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1  / 40;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(acosh) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  ensure(SELECT(a0 > 1, a0*a0 != 1));

  expansion_coef[0] = acosh(a0);
  NUM          xcf1 = 1 / sqrt(a0*a0 - 1);
  expansion_coef[1] =                        xcf1;
  expansion_coef[2] = -        a0          * xcf1*xcf1*xcf1                     / 2;
  expansion_coef[3] = (1     + 2*a0*a0   ) * xcf1*xcf1*xcf1*xcf1*xcf1           / 6;
  expansion_coef[4] = (-3*a0 - 2*a0*a0*a0) * xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 / 8;
  expansion_coef[5] = (3     + 24*a0*a0 + 8*a0*a0*a0*a0)
                      *            xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1*xcf1 / 40;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(atanh) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  ensure(SELECT(fabs(a0) < 1, a0*a0 != 1));

  expansion_coef[0] = atanh(a0);
  NUM          xcf1 = 1 / (1 - a0*a0);
  expansion_coef[1] =                                   xcf1;
  expansion_coef[2] = a0                              * xcf1*xcf1;
  expansion_coef[3] = (1.0/3 + a0*a0)                 * xcf1*xcf1*xcf1;
  expansion_coef[4] = (a0    + a0*a0*a0)              * xcf1*xcf1*xcf1*xcf1;
  expansion_coef[5] = (1.0/5 + a0*a0*a0*a0 + 2*a0*a0) * xcf1*xcf1*xcf1*xcf1*xcf1;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(acoth) (const T *a, T *c)
{
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  ensure(SELECT(fabs(a0) > 1, a0 != 0 && a0*a0 != 1));

  expansion_coef[0] = atanh(1/a0);
  NUM          xcf1 = 1 / (-1 + a0*a0);
  expansion_coef[1] = -                                  xcf1;
  expansion_coef[2] =   a0                             * xcf1*xcf1;
  expansion_coef[3] = (-1.0/3 - a0*a0)                 * xcf1*xcf1*xcf1;
  expansion_coef[4] = (a0     + a0*a0*a0)              * xcf1*xcf1*xcf1*xcf1;
  expansion_coef[5] = (-1.0/5 - a0*a0*a0*a0 - 2*a0*a0) * xcf1*xcf1*xcf1*xcf1*xcf1;

  fixed_point_iteration(a,c,to,expansion_coef);
}

void
FUN(erf) (const T *a, T *c)
{
  // ERF(X) is the integral from 0 to x from [2/sqrt(pi) * exp(-x*x)]
  assert(a && c);
  ensure(a->d == c->d);

  ord_t to = MIN(c->mo,c->d->trunc);
  ensure(to <= 5);

  NUM expansion_coef[MANUAL_EXPANSION_ORD+1], a0 = a->coef[0];
  // coeff from Berz's TPSALib
  static const
  num_t a1 =  0.254829592,
        a2 = -0.284496736,
        a3 =  1.421413741,
        a4 = -1.453152027,
        a5 =  1.061405429,
        p  =  0.327591100,
        p2 =  0.886226925452758013649083741670572591398774728061193564106903; // sqrt(atan(1.0)),
  NUM   t  = 1 / (1 + p*a0),
        e1 = exp(-a0*a0),
        e2 = 1 - t*(a1+t*(a2+t*(a3+t*(a4+t*a5))))*e1;
  expansion_coef[0] = e2;
  expansion_coef[1] =                                        e1 / p2;
  expansion_coef[2] = -                                   a0*e1 / p2;
  expansion_coef[3] = (-1             +  2*a0*a0)      /   3*e1 / p2;
  expansion_coef[4] = (12*a0          -  8*a0*a0*a0)   /  24*e1 / p2;
  expansion_coef[5] = (16*a0*a0*a0*a0 - 48*a0*a0 + 12) / 120*e1 / p2;

  fixed_point_iteration(a,c,to,expansion_coef);
}
