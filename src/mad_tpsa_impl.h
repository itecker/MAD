#ifndef MAD_TPSA_IMPL_H
#define MAD_TPSA_IMPL_H

/*
 o----------------------------------------------------------------------------o
 |
 | Truncated Power Series Algebra module implementation
 |
 | Methodical Accelerator Design - Copyright CERN 2015
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

#include "mad_bit.h"
#include "mad_tpsa.h"

// --- types -----------------------------------------------------------------o

struct tpsa { // warning: must be kept identical to LuaJIT definition (cmad.lua)
  desc_t *desc;
  ord_t   lo, hi, mo; // lowest/highest used ord, trunc ord
  bit_t   nz;
  int     is_tmp;
  num_t   coef[];
};

// --- helpers ---------------------------------------------------------------o

#define T           tpsa_t
#define NUM         num_t
#define FUN(name)   MKNAME(mad_tpsa_,name)
#define PFX(name)   name
#define VAL(num)    num
#define FMT         "%g"
#define SELECT(R,C) R

// ---------------------------------------------------------------------------o

#endif // MAD_TPSA_IMPL_H