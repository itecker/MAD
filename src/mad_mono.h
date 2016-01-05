#ifndef MAD_MONO_H
#define MAD_MONO_H

/*
 o----------------------------------------------------------------------------o
 |
 | Monomial module interface
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
  
  Purpose:
  - provide some functions to handle monomials as array of ord_t
 
  Information:
  - parameters ending with an underscope can be null.

  Errors:
  - TODO

 o----------------------------------------------------------------------------o
 */

// --- types -----------------------------------------------------------------o

typedef unsigned char ord_t;

// --- interface -------------------------------------------------------------o

void  mad_mono_fill  (int n,       ord_t a[n], ord_t v);
void  mad_mono_cpy   (int n, const ord_t a[n],                   ord_t r[n]);

ord_t mad_mono_max   (int n, const ord_t a[n]);
int   mad_mono_ord   (int n, const ord_t a[n]);
int   mad_mono_equ   (int n, const ord_t a[n], const ord_t b[n]);
int   mad_mono_leq   (int n, const ord_t a[n], const ord_t b[n]);
int   mad_mono_rcmp  (int n, const ord_t a[n], const ord_t b[n]);

void  mad_mono_add   (int n, const ord_t a[n], const ord_t b[n], ord_t r[n]);
void  mad_mono_sub   (int n, const ord_t a[n], const ord_t b[n], ord_t r[n]);

void  mad_mono_sort  (int n, const ord_t a[n], int idxs[n]);
void  mad_mono_print (int n, const ord_t a[n]);

// ---------------------------------------------------------------------------o

#endif //  MAD_MONO_H
