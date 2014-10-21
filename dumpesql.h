/*
@(#)File:           $RCSfile: dumpesql.h,v $
@(#)Version:        $Revision: 1.9 $
@(#)Last changed:   $Date: 2008/02/29 22:52:44 $
@(#)Purpose:        ESQL/C Type Dumper Code
@(#)Author:         J Leffler
@(#)Copyright:      (C) JLSS 2005,2007-08
@(#)Product:        IBM Informix Database Driver for Perl DBI Version 2008.0229 (2008-02-29)
*/

/*TABSTOP=4*/

#ifndef JLSS_ID_DUMPESQL_H
#define JLSS_ID_DUMPESQL_H

#ifdef  __cplusplus
extern "C" {
#endif

#ifdef MAIN_PROGRAM
#ifndef lint
/* Prevent over-aggressive optimizers from eliminating ID string */
extern const char jlss_id_dumpesql_h[];
const char jlss_id_dumpesql_h[] = "@(#)$Id: dumpesql.h,v 1.9 2008/02/29 22:52:44 jleffler Exp $";
#endif /* lint */
#endif /* MAIN_PROGRAM */

#include <stdio.h>
#include "sqlca.h"
#include "sqlda.h"
#include "value.h"

#ifndef TU_FRACDIGITS
#define TU_FRACDIGITS(q)    ((TU_END(q) < TU_SECOND) ? 0 : (TU_END(q) - TU_SECOND))
#endif /* TU_FRACDIGITS */

/* A (poor) simulation of C++ const_cast<type>(value) */
#ifndef CONST_CAST
#define CONST_CAST(type, value) ((type)(value))
#endif /* CONST_CAST */

#ifndef DIM
#define DIM(x)  (sizeof(x)/sizeof(*(x)))
#endif /* DIM */

#ifndef IFX_DEC_T
#define IFX_DEC_T
typedef dec_t ifx_dec_t;
#endif /* IFX_DEC_T */

#ifndef IFX_VALUE_T
#define IFX_VALUE_T
typedef value_t ifx_value_t;
#endif /* IFX_VALUE_T */

#ifndef IFX_LOC_T
#define IFX_LOC_T
typedef loc_t   ifx_loc_t;
#endif /* IFX_LOC_T */

/* XXX Kludge - but hard to avoid right now */
#ifdef HAVE_DATEZONE_H

#include "datezone.h"
extern void dump_dtimetz(FILE *fp, const char *tag, const ifx_dtimetz_t *dp);

#else

typedef dtime_t  ifx_dtime_t;
typedef intrvl_t ifx_intrvl_t;

#endif /* HAVE_DATEZONE_H */

extern void dump_blob(FILE *fp, const char *tag, const ifx_loc_t *blob);
extern void dump_datetime(FILE *fp, const char *tag, const ifx_dtime_t *dp);
extern void dump_decimal(FILE *fp, const char *tag, const ifx_dec_t *dp);
extern void dump_interval(FILE *fp, const char *tag, const ifx_intrvl_t *ip);
extern void dump_sqlca(FILE *fp, const char *tag, const ifx_sqlca_t *psqlca);
extern void dump_sqlda(FILE *fp, const char *tag, const ifx_sqlda_t *desc);
extern void dump_sqldescriptor(FILE *fp, const char *tag, const char *name);
extern void dump_sqlva(FILE *fp, int item, const ifx_sqlvar_t *sqlvar);
extern void dump_value(FILE *fp, const char *tag, const ifx_value_t *vp);

extern void dumpsqlca(FILE *fp, const char *tag);

extern void dump_print(FILE *fp, const char *fmt, ...);

extern int  dump_setindent(int level);

extern const char *dump_getindent(void);

#ifdef  __cplusplus
}
#endif

#endif /* JLSS_ID_DUMPESQL_H */
