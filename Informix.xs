/*
 * @(#)$Id: Informix.xs,v 100.5 2002/11/18 23:34:25 jleffler Exp $ 
 *
 * Copyright 1994-95 Tim Bunce
 * Copyright 1995-96 Alligator Descartes
 * Copyright 1996-99 Jonathan Leffler
 * Copyright 2000    Informix Software Inc
 * Copyright 2002    IBM
 *
 * You may distribute under the terms of either the GNU General Public
 * License or the Artistic License, as specified in the Perl README file.
 */

/*TABSTOP=4*/

#include "Informix.h"

/* For ActiveState Perl on NT */
/* Change from Michael Kopchenov <myk@informix.com> */
#ifdef PERL_OBJECT
#include "XSLock.h"
#undef fprintf
#define fprintf (fprintf)
#endif

DBISTATE_DECLARE;

/* Assume string concatenation is available */
#ifndef lint
static const char rcs[] = "@(#)$Id: Informix.xs,v 100.5 2002/11/18 23:34:25 jleffler Exp $";
static const char esqlc_ver[] =
	"@(#)" ESQLC_VERSION_STRING;
#endif

MODULE = DBD::Informix	PACKAGE = DBD::Informix

I32
constant()
    PROTOTYPE:
    ALIAS:
	IX_SMALLINT   = SQLSMINT
	IX_INTEGER    = SQLINT
	IX_SERIAL     = SQLSERIAL
	IX_INT8       = SQLINT8
	IX_SERIAL8    = SQLSERIAL8
	IX_DECIMAL    = SQLDECIMAL
	IX_MONEY      = SQLMONEY
	IX_FLOAT      = SQLFLOAT
	IX_SMALLFLOAT = SQLSMFLOAT
	IX_CHAR       = SQLCHAR
	IX_VARCHAR    = SQLVCHAR
	IX_NCHAR      = SQLNCHAR
	IX_NVARCHAR   = SQLNVCHAR
	IX_LVARCHAR   = SQLLVARCHAR
	IX_BOOLEAN    = SQLBOOL
	IX_DATE       = SQLDATE
	IX_DATETIME   = SQLDTIME
	IX_INTERVAL   = SQLINTERVAL
	IX_BYTE       = SQLBYTES
	IX_TEXT       = SQLTEXT
	IX_SET        = SQLSET
	IX_MULTISET   = SQLMULTISET
	IX_LIST       = SQLLIST
	IX_ROW        = SQLROW
	IX_COLLECTION = SQLCOLLECTION
	IX_VARUDT     = SQLUDTVAR
	IX_FIXUDT     = SQLUDTFIXED
	# In the Informix system catalog, CLOB and BLOB types are simply
	# specific cases of a fixed UDT.  They seem to have extended ids
	# 10, 11.  However, they are also base types (opaque), and there
	# is storage information for them in the create table statement
	# (a PUT clause after the column list).  We need to handle them
	# specially, so define unique values for them in dbdimp.h.
	IX_CLOB       = DBD_IX_SQLCLOB
	IX_BLOB       = DBD_IX_SQLBLOB
    CODE:
    RETVAL = ix;
    OUTPUT:
    RETVAL

INCLUDE: Informix.xsi

MODULE = DBD::Informix	PACKAGE = DBD::Informix::dr

# Initialize the DBD::Informix driver data structure
void
driver_init(drh)
	SV *        drh
	CODE:
	ST(0) = dbd_ix_dr_driver(drh) ? &sv_yes : &sv_no;

# Fetch a driver attribute.  The keys are always strings.
# For some reason, not a part of the DBI standard
void
FETCH(drh, keysv)
	SV *        drh
	SV *        keysv
	CODE:
	D_imp_drh(drh);
	SV *valuesv = dbd_ix_dr_FETCH_attrib(imp_drh, keysv);
	if (!valuesv)
		valuesv = DBIc_DBISTATE(imp_drh)->get_attr(drh, keysv);
	ST(0) = valuesv;    /* dbd_dr_FETCH_attrib did sv_2mortal  */

# Utility function to list available databases
void
data_sources(drh)
	SV *drh
	PPCODE:
# Up until recently, a database name could consist of up to 18 characters
# in OnLine, plus the name of the server (no limit defined, assume 18
# again), plus the at sign and the NUL at the end.  With the 9.2 release,
# the server and database names will be able to go to 128 characters, hence
# the increased limits.
#define MAXDBS 100
#define MAXDBSSIZE	(128+128+2)
#define FASIZE (MAXDBS * MAXDBSSIZE)
	int sqlcode;
	int ndbs;
	int i;
	char *dbsname[MAXDBS + 1];
	char dbsarea[FASIZE];
	sqlcode = sqgetdbs(&ndbs, dbsname, MAXDBS, dbsarea, FASIZE);
	if (sqlcode != 0)
	{
		dbd_ix_seterror(sqlcode);
	}
	else
	{
		for (i = 0; i < ndbs; ++i)
		{
			SV *sv = newSVpvf("dbi:Informix", 0);
			# Let Perl calculate the length of the name
			XPUSHs(sv_2mortal(newSVpvf("dbi:Informix:%s", dbsname[i])));
		}
	}

MODULE = DBD::Informix    PACKAGE = DBD::Informix::db

void
preset(dbh, dbattr)
	SV *        dbh
	SV *        dbattr
	CODE:
	{
	D_imp_dbh(dbh);
	ST(0) = dbd_ix_db_preset(imp_dbh, dbattr) ? &sv_yes : &sv_no;
	}

MODULE = DBD::Informix    PACKAGE = DBD::Informix::st

# end of Informix.xs
