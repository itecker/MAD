/*
 o----------------------------------------------------------------------------o
 |
 | Vector module implementation
 |
 | Methodical Accelerator Design - Copyright CERN 2015
 | Support: http://cern.ch/mad  - mad at cern.ch
 | Authors: L. Deniau, laurent.deniau at cern.ch
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
#include <complex.h>
#include <assert.h>

#include "mad_log.h"
#include "mad_mem.h"
#include "mad_vec.h"

// --- implementation --------------------------------------------------------o

#define CHKR    assert( r )
#define CHKX    assert( x )
#define CHKXY   assert( x && y )
#define CHKXR   assert( x && r )
#define CHKYR   assert( y && r )
#define CHKXYR  assert( x && y && r )

// rename to CNUM
#define CNUM(re,im) (* (cnum_t*) & (num_t[2]) { re, im })

// --- vec

void mad_vec_fill (num_t x, num_t r[], size_t n)
{ CHKR; for (size_t i=0; i < n; i++) r[i] = x; }

void mad_vec_copy (const num_t x[], num_t r[], size_t n)
{ CHKXR; if (x != r) for (size_t i=0; i < n; i++) r[i] = x[i]; }

void mad_vec_copyv (const num_t x[], cnum_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i]; }

void mad_vec_cvec (const num_t x[], const num_t y[], cnum_t r[], size_t n)
{ assert( r && (x || y) );
  if (x && y) for (size_t i=0; i < n; i++) r[i] = CNUM(x[i],y[i]);
  else if (x) for (size_t i=0; i < n; i++) r[i] =      x[i]      ;
  else        for (size_t i=0; i < n; i++) r[i] = CNUM(0   ,y[i]);
}

num_t mad_vec_dot (const num_t x[], const num_t y[], size_t n)
{ CHKXY; num_t r=0; for (size_t i=0; i < n; i++) r += x[i] * y[i]; return r; }

cnum_t mad_vec_dotv (const  num_t x[], const cnum_t y[], size_t n)
{ CHKXY; cnum_t r=0; for (size_t i=0; i < n; i++) r += x[i] * y[i]; return r; }

void mad_vec_dotv_r (const  num_t x[], const cnum_t y[], cnum_t *r, size_t n)
{ CHKR; *r = mad_vec_dotv(x, y, n); }

void mad_vec_add (const num_t x[], const num_t y[], num_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] + y[i]; }

void mad_vec_addn (const num_t x[], num_t y, num_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i] + y; }

void mad_vec_addc (const num_t x[], cnum_t y, cnum_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i] + y; }

void mad_vec_addc_r (const num_t x[], num_t y_re, num_t y_im, cnum_t r[], size_t n)
{ mad_vec_addc(x, CNUM(y_re,y_im), r, n); }

void mad_vec_sub (const num_t x[], const num_t y[], num_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] - y[i]; }

void mad_vec_subv (const num_t x[], const cnum_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] - y[i]; }

void mad_vec_subn (const num_t y[], num_t x, num_t r[], size_t n)
{ CHKYR; for (size_t i=0; i < n; i++) r[i] = x - y[i]; }

void mad_vec_subc (const num_t y[], cnum_t x, cnum_t r[], size_t n)
{ CHKYR; for (size_t i=0; i < n; i++) r[i] = x - y[i]; }

void mad_vec_subc_r (const num_t y[], num_t x_re, num_t x_im, cnum_t r[], size_t n)
{ mad_vec_subc(y, CNUM(x_re,x_im), r, n); }

void mad_vec_mul (const num_t x[], const num_t y[], num_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] * y[i]; }

void mad_vec_muln (const num_t x[], num_t y, num_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i] * y; }

void mad_vec_mulc (const num_t x[], cnum_t y, cnum_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i] * y; }

void mad_vec_mulc_r (const num_t x[], num_t y_re, num_t y_im, cnum_t r[], size_t n)
{ mad_vec_mulc(x, CNUM(y_re,y_im), r, n); }

void mad_vec_div (const num_t x[], const num_t y[], num_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] / y[i]; }

void mad_vec_divv (const num_t x[], const cnum_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] / y[i]; }

void mad_vec_divn (const num_t y[], num_t x, num_t r[], size_t n)
{ CHKYR; for (size_t i=0; i < n; i++) r[i] = x / y[i]; }

void mad_vec_divc (const num_t y[], cnum_t x, cnum_t r[], size_t n)
{ CHKYR; for (size_t i=0; i < n; i++) r[i] = x / y[i]; }

void mad_vec_divc_r (const num_t y[], num_t x_re, num_t x_im, cnum_t r[], size_t n)
{  mad_vec_divc(y, CNUM(x_re,x_im), r, n); }

void mad_vec_center (const num_t x[], num_t r[], size_t n)
{ CHKXR;
  num_t mu = 0;
  for (size_t i=0; i < n; i++) mu += x[i];
  mu /= n;
  for (size_t i=0; i < n; i++) r[i] = x[i] - mu;
}

// --- cvec

void mad_cvec_fill (cnum_t x, cnum_t r[], size_t n)
{ CHKR; for (size_t i=0; i < n; i++) r[i] = x; }

void mad_cvec_fill_r (num_t x_re, num_t x_im, cnum_t r[], size_t n)
{ mad_cvec_fill(CNUM(x_re,x_im), r, n); }

void mad_cvec_copy (const cnum_t x[], cnum_t r[], size_t n)
{ mad_vec_copy((const num_t*)x, (num_t*)r, 2*n); }

void mad_cvec_vec (const cnum_t x[], num_t re[], num_t ri[], size_t n)
{ assert( x && (re || ri) );
  if (re && ri) for (size_t i=0; i < n; i++) re[i]=creal(x[i]),
                                             ri[i]=cimag(x[i]);
  else if (re)  for (size_t i=0; i < n; i++) re[i]=creal(x[i]);
  else          for (size_t i=0; i < n; i++) ri[i]=cimag(x[i]);
}

void mad_cvec_conj (const cnum_t x[], cnum_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = conj(x[i]); }

cnum_t mad_cvec_dot (const cnum_t x[], const cnum_t y[], size_t n)
{ CHKXY; cnum_t r=0; for (size_t i=0; i < n; i++) r += conj(x[i])*y[i]; return r; }

void mad_cvec_dot_r (const cnum_t x[], const cnum_t y[], cnum_t *r, size_t n)
{ CHKR; *r = mad_cvec_dot(x, y, n); }

cnum_t mad_cvec_dotv (const cnum_t x[], const num_t y[], size_t n)
{ CHKXY; cnum_t r=0; for (size_t i=0; i < n; i++) r += conj(x[i])*y[i]; return r; }

void mad_cvec_dotv_r (const cnum_t x[], const num_t y[], cnum_t *r, size_t n)
{ CHKR; *r = mad_cvec_dotv(x, y, n); }

void mad_cvec_add (const cnum_t x[], const cnum_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] + y[i]; }

void mad_cvec_addv (const cnum_t x[], const num_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] + y[i]; }

void mad_cvec_addn (const cnum_t x[], num_t y, cnum_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i] + y; }

void mad_cvec_addc (const cnum_t x[], cnum_t y, cnum_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i] + y; }

void mad_cvec_addc_r (const cnum_t x[], num_t y_re, num_t y_im, cnum_t r[], size_t n)
{ mad_cvec_addc(x, CNUM(y_re,y_im), r, n); }

void mad_cvec_sub (const cnum_t x[], const cnum_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] - y[i]; }

void mad_cvec_subv (const cnum_t x[], const num_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] - y[i]; }

void mad_cvec_subn (const cnum_t y[], num_t x, cnum_t r[], size_t n)
{ CHKYR; for (size_t i=0; i < n; i++) r[i] = x - y[i]; }

void mad_cvec_subc (const cnum_t y[], cnum_t x, cnum_t r[], size_t n)
{ CHKYR; for (size_t i=0; i < n; i++) r[i] = x - y[i];; }

void mad_cvec_subc_r (const cnum_t y[], num_t x_re, num_t x_im, cnum_t r[], size_t n)
{ mad_cvec_subc(y, CNUM(x_re,x_im), r, n); }

void mad_cvec_mul (const cnum_t x[], const cnum_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] * y[i]; }

void mad_cvec_mulv (const cnum_t x[], const num_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] * y[i]; }

void mad_cvec_muln (const cnum_t x[], num_t y, cnum_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i] * y; }

void mad_cvec_mulc (const cnum_t x[], cnum_t y, cnum_t r[], size_t n)
{ CHKXR; for (size_t i=0; i < n; i++) r[i] = x[i] * y; }

void mad_cvec_mulc_r (const cnum_t x[], num_t y_re, num_t y_im, cnum_t r[], size_t n)
{ mad_cvec_mulc(x, CNUM(y_re,y_im), r, n); }

void mad_cvec_div (const cnum_t x[], const cnum_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] / y[i]; }

void mad_cvec_divv (const cnum_t x[], const num_t y[], cnum_t r[], size_t n)
{ CHKXYR; for (size_t i=0; i < n; i++) r[i] = x[i] / y[i]; }

void mad_cvec_divn (const cnum_t y[], num_t x, cnum_t r[], size_t n)
{ CHKYR; for (size_t i=0; i < n; i++) r[i] = x / y[i]; }

void mad_cvec_divc (const cnum_t y[], cnum_t x, cnum_t r[], size_t n)
{ CHKYR; for (size_t i=0; i < n; i++) r[i] = x / y[i]; }

void mad_cvec_divc_r (const cnum_t y[], num_t x_re, num_t x_im, cnum_t r[], size_t n)
{ mad_cvec_divc(y, CNUM(x_re,x_im), r, n); }

void mad_cvec_center (const cnum_t x[], cnum_t r[], size_t n)
{ CHKXR;
  cnum_t mu = 0;
  for (size_t i=0; i < n; i++) mu += x[i];
  mu /= n;
  for (size_t i=0; i < n; i++) r[i] = x[i] - mu;
}

// -- FFT ---------------------------------------------------------------------o

#include <fftw3.h>

void // x [n] -> r [n]
mad_vec_fft (const num_t x[], cnum_t r[], size_t n)
{
  CHKXR;
  mad_alloc_tmp(cnum_t, cx, n);
  mad_vec_copyv(x, cx, n);
  mad_cvec_fft(cx, r, n);
  mad_free_tmp(cx);
}

void // x [n] -> r [n/2+1]
mad_vec_rfft (const num_t x[], cnum_t r[], size_t n)
{
  CHKXR;
  fftw_plan p = fftw_plan_dft_r2c_1d(n, (num_t*)x, r, FFTW_ESTIMATE);
  fftw_execute(p);
  fftw_destroy_plan(p);
}

void
mad_cvec_fft (const cnum_t x[], cnum_t r[], size_t n)
{
  CHKXR;
  fftw_plan p = fftw_plan_dft_1d(n, (cnum_t*)x, r, FFTW_FORWARD, FFTW_ESTIMATE);
  fftw_execute(p);
  fftw_destroy_plan(p);
}

void
mad_cvec_ifft(const cnum_t x[], cnum_t r[], size_t n)
{
  CHKXR;
  fftw_plan p = fftw_plan_dft_1d(n, (cnum_t*)x, r, FFTW_BACKWARD, FFTW_ESTIMATE);
  fftw_execute(p);
  fftw_destroy_plan(p);
  mad_cvec_muln(r, 1.0/n, r, n);
}

void // x [n/2+1] -> r [n]
mad_cvec_irfft (const cnum_t x[], num_t r[], size_t n)
{
  CHKXR;
  size_t nn = n/2+1;
  mad_alloc_tmp(cnum_t, cx, nn);
  mad_cvec_copy(x, cx, nn);
  fftw_plan p = fftw_plan_dft_c2r_1d(n, cx, r, FFTW_ESTIMATE);
  fftw_execute(p);
  fftw_destroy_plan(p);
  mad_free_tmp(cx);
  mad_vec_muln(r, 1.0/n, r, n);
}

// -- NFFT --------------------------------------------------------------------o

#if 0
#include <nfft3.h>

void
mad_cvec_nfft (const cnum_t x[], const num_t x_pos[], cnum_t r[], size_t n, size_t n_pos)
{
  assert( x && x_pos && r );
  nfft_plan p;
  nfft_init_1d(&p, n, n_pos);
  memcpy(p.x, x_pos, p.M_total * sizeof *x_pos); // TODO:  resample from n_pos to p.M_total?
  if(p.nfft_flags & PRE_ONE_PSI) nfft_precompute_one_psi(&p);
  memcpy(p.f_hat, x, p.N_total * sizeof *x); // TODO: resample from n to p.N_total?
  nfft_trafo(&p);
  memcpy(r, p.f, p.N_total * sizeof *r); // TODO: resample from p.N_total to n?
  nfft_finalize(&p);
}

void
mad_cvec_infft (const cnum_t x[], const num_t x_pos[], cnum_t r[], size_t n, size_t n_pos)
{
  assert( x && x_pos && r );
  nfft_plan p;
  nfft_init_1d(&p, n, n_pos);
  memcpy(p.x, x_pos, p.M_total * sizeof *x_pos); // TODO:  resample from n_pos to p.M_total
  if(p.nfft_flags & PRE_ONE_PSI) nfft_precompute_one_psi(&p);
  memcpy(p.f, x, p.N_total * sizeof *x); // TODO: resample from n to p.N_total
  nfft_adjoint(&p);
  memcpy(r, p.f_hat, p.N_total * sizeof *r); // TODO: resample from p.N_total to n?
  nfft_finalize(&p);
}

void
mad_cvec_nnfft (const cnum_t x[], const num_t x_pos[], const num_t f_pos[], cnum_t r[], size_t n, size_t n_pos)
{
  assert( x && x_pos && f_pos && r );
}

void
mad_cvec_innfft (const cnum_t x[], const num_t x_pos[], const num_t f_pos[], cnum_t r[], size_t n, size_t n_pos)
{
  assert( x && x_pos && f_pos && r );
}
#endif
