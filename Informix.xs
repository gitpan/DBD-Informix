/*
 * @(#)Informix.xs	25.8 96/11/25 20:12:20
 *
 * $Derived-From: Informix.xs,v 1.1 1996/04/14 16:21:36 descarte Archaic $
 *
 * Portions Copyright (c) 1994,1995 Tim Bunce
 * Portions Copyright (c) 1995,1996 Alligator Descartes
 * Portions Copyright (c) 1996      Jonathan Leffler
 *
 * You may distribute under the terms of either the GNU General Public
 * License or the Artistic License, as specified in the Perl README file.
 */

#include "Informix.h"

/* --- Variables --- */

DBISTATE_DECLARE;

/* Assume string concatenation is available */
#ifndef lint
static const char sccs[] = "@(#)Informix.xs	25.8 96/11/25";
static const char esqlc_ver[] = "@(#)" ESQLC_VERSION_STRING;
#endif

MODULE = DBD::Informix	PACKAGE = DBD::Informix

REQUIRE:    1.929
PROTOTYPES: ENABLE

BOOT:
	items = 0;	/* avoid 'unused variable' warning */
	DBISTATE_INIT;
	/* XXX this interface will change: */
	DBI_IMP_SIZE("DBD::Informix::dr::imp_data_size", sizeof(imp_drh_t));
	DBI_IMP_SIZE("DBD::Informix::db::imp_data_size", sizeof(imp_dbh_t));
	DBI_IMP_SIZE("DBD::Informix::st::imp_data_size", sizeof(imp_sth_t));
	dbd_dr_init(DBIS);

void
errstr(h)
	SV *	h
	CODE:
	/* called from DBI::var TIESCALAR code for $DBI::errstr	*/
	D_imp_xxh(h);
	ST(0) = sv_mortalcopy(DBIc_ERRSTR(imp_xxh));

MODULE = DBD::Informix	PACKAGE = DBD::Informix::dr

void
driver_init(drh)
	SV *        drh
	CODE:
	ST(0) = dbd_ix_driver(drh) ? &sv_yes : &sv_no;

void
disconnect_all(drh)
	SV *        drh
	CODE:
	if (!dirty && !SvTRUE(perl_get_sv("DBI::PERL_ENDING",0)))
	{
		D_imp_drh(drh);
		sv_setiv(DBIc_ERR(imp_drh), (IV)1);
		sv_setpv(DBIc_ERRSTR(imp_drh),
				(char*)"disconnect_all not implemented");
		DBIh_EVENT2(drh, ERROR_event,
				DBIc_ERR(imp_drh), DBIc_ERRSTR(imp_drh));
		XSRETURN(0);
	}
	/* perl_destruct with perl_destruct_level and $SIG{__WARN__} set	*/
	/* to a code ref core dumps when sv_2cv triggers warn loop.		*/
	if (perl_destruct_level)
	perl_destruct_level = 0;
	XST_mIV(0, 1);

void
_ListDBs( drh )
	SV *drh
	PPCODE:
# Note that a database name could consist of up to 18 characters in OnLine,
# plus the name of the server (no limit defined, assume 18 again), plus the
# at sign and the NUL at the end.
#define MAXDBS 100
#define MAXDBSSIZE	(18+18+2)
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
			# Let Perl calculate the length of the name
			XPUSHs(sv_2mortal((SV*)newSVpv(dbsname[i], 0)));
		}
	}

MODULE = DBD::Informix    PACKAGE = DBD::Informix::db

void
_login(dbh, dbname, uid, pwd)
	SV *	dbh
	char *	dbname
	char *	uid
	char *	pwd
	CODE:
	ST(0) = dbd_db_login(dbh, dbname, uid, pwd) ? &sv_yes : &sv_no;

void
commit(dbh)
	SV *        dbh
	CODE:
	ST(0) = dbd_db_commit(dbh) ? &sv_yes : &sv_no;

void
rollback(dbh)
	SV *        dbh
	CODE:
	ST(0) = dbd_db_rollback(dbh) ? &sv_yes : &sv_no;

void
STORE(dbh, keysv, valuesv)
	SV *        dbh
	SV *        keysv
	SV *        valuesv
	CODE:
	ST(0) = &sv_yes;
	if (!dbd_db_STORE(dbh, keysv, valuesv))
	if (!DBIS->set_attr(dbh, keysv, valuesv))
		ST(0) = &sv_no;

void
FETCH(dbh, keysv)
	SV *        dbh
	SV *        keysv
	CODE:
	SV *valuesv = dbd_db_FETCH(dbh, keysv);
	if (!valuesv)
	valuesv = DBIS->get_attr(dbh, keysv);
	ST(0) = valuesv;    /* dbd_db_FETCH did sv_2mortal  */

void
disconnect(dbh)
	SV *        dbh
	CODE:
	D_imp_dbh(dbh);
	if (!DBIc_ACTIVE(imp_dbh))
	{
		XSRETURN_YES;
	}
	/* Check for disconnect() being called whilst refs to cursors       */
	/* still exists. This needs some more thought.                      */
	if (DBIc_ACTIVE_KIDS(imp_dbh) && DBIc_WARN(imp_dbh) && !dirty)
	{
		warn("disconnect(%s) invalidates %d active cursor(s)",
			SvPV(dbh,na), (int)DBIc_ACTIVE_KIDS(imp_dbh));
	}
	ST(0) = dbd_db_disconnect(dbh) ? &sv_yes : &sv_no;

void
immediate(dbh, stmt)
	SV	*dbh
	char *stmt
	CODE:
	ST(0) = dbd_ix_immediate(dbh, stmt) ? &sv_yes : &sv_no;

void
DESTROY(dbh)
	SV *        dbh
	PPCODE:
	D_imp_dbh(dbh);
	ST(0) = &sv_yes;
	if (!DBIc_IMPSET(imp_dbh))
	{        /* was never fully set up       */
		if (DBIc_WARN(imp_dbh) && !dirty && dbis->debug >= 2)
			 warn("Database handle %s DESTROY ignored - never set up",
				SvPV(dbh,na));
	}
	else
	{
		if (DBIc_ACTIVE(imp_dbh))
		{
			if (DBIc_WARN(imp_dbh) && !dirty)
				 warn("Database handle destroyed without explicit disconnect");
			dbd_db_disconnect(dbh);
		}
		dbd_db_destroy(dbh);
	}

MODULE = DBD::Informix    PACKAGE = DBD::Informix::st

void
_prepare(sth, statement, attribs=Nullsv)
	SV *        sth
	char *      statement
	SV *	attribs
	CODE:
	DBD_ATTRIBS_CHECK("_prepare", sth, attribs);
	ST(0) = dbd_st_prepare(sth, statement, attribs) ? &sv_yes : &sv_no;

void
rows(sth)
	SV *        sth
	CODE:
	XST_mIV(0, dbd_st_rows(sth));

void
bind_param(sth, param, value, attribs=Nullsv)
	SV *	sth
	SV *	param
	SV *	value
	SV *	attribs
	CODE:
	croak("DBD::Informix::bind_param_inout is not implemented\n");
	/*
	DBD_ATTRIBS_CHECK("bind_param", sth, attribs);
	if (dbd_st_bind_ph(sth, param, value, attribs, FALSE, 0))
		ST(0) = &sv_yes;
	else
		ST(0) = &sv_no;
	*/

void
bind_param_inout(sth, param, value_ref, maxlen, attribs=Nullsv)
	SV *	sth
	SV *	param
	SV *	value_ref
	IV 		maxlen
	SV *	attribs
	CODE:
	croak("DBD::Informix::bind_param_inout is not implemented\n");
	/*
	DBD_ATTRIBS_CHECK("bind_param_inout", sth, attribs);
	if (!SvROK(value_ref))
		croak("bind_param_inout needs a reference to the value");
	if (dbd_st_bind_ph(sth, param, SvRV(value_ref), attribs, TRUE, maxlen))
		ST(0) = &sv_yes;
	else
		ST(0) = &sv_no;
	*/

void
execute(sth, ...)
	SV *        sth
	CODE:
	D_imp_sth(sth);
	int retval;

	if (items > 1)
	{
		/*
		if (items - 1 != DBIc_NUM_PARAMS(imp_sth))
		{
			croak("execute called with %ld bind variables, %d needed",
				items-1, DBIc_NUM_PARAMS(imp_sth));
				XSRETURN_UNDEF;
		}
		*/
		if (dbd_ix_setbindnum(imp_sth, items - 1))
		{
			int i;
			int error = 0;
			for(i = 1; i < items; i++)
			{
				if (!dbd_ix_bindsv(imp_sth, i, ST(i)))
						++error;
			}
			if (error)
			{
				XSRETURN_UNDEF;	/* dbd_ix_bindsv() already registered error	*/
			}
		}
	}

	retval = dbd_st_execute(imp_sth);
	if (retval < 0)
		XST_mUNDEF(0);		/* error        		*/
	else if (retval == 0)
		XST_mPV(0, "0E0");	/* true but zero		*/
	else
		XST_mIV(0, retval);	/* typically 1 or rowcount	*/

void
fetch(sth)
	SV *	sth
	CODE:
	AV *av = dbd_st_fetch(sth);
	ST(0) = (av) ? sv_2mortal(newRV((SV *)av)) : &sv_undef;

void
fetchrow(sth)
	SV *	sth
	PPCODE:
	D_imp_sth(sth);
	AV *av;
	if (DBIc_COMPAT(imp_sth) && GIMME == G_SCALAR)
	{
		XSRETURN_IV(DBIc_NUM_FIELDS(imp_sth));
	}
	else
	{
		av = dbd_st_fetch(sth);
		if (av)
		{
			int num_fields = AvFILL(av)+1;
			int i;
			EXTEND(sp, num_fields);
			for(i = 0; i < num_fields; ++i)
			{
				PUSHs(AvARRAY(av)[i]);
			}
		}
	}

void
blob_read(sth, field, offset, len, destrv=Nullsv, destoffset=0)
	SV *        sth
	int field
	long        offset
	long        len
	SV *	destrv
	long	destoffset
	CODE:
	croak("DBD::Informix::blob_read is not implemented\n");
	/*
	if (!destrv)
		destrv = sv_2mortal(newRV(newSV(0)));
	if (dbd_st_blob_read(sth, field, offset, len, destrv, destoffset))
		ST(0) = SvRV(destrv);
	else
		ST(0) = &sv_undef;
	*/

void
STORE(sth, keysv, valuesv)
	SV *	sth
	SV *        keysv
	SV *        valuesv
	CODE:
	ST(0) = &sv_yes;
	if (!dbd_st_STORE(sth, keysv, valuesv))
	if (!DBIS->set_attr(sth, keysv, valuesv))
		ST(0) = &sv_no;

void
FETCH(sth, keysv)
	SV *        sth
	SV *        keysv
	CODE:
	SV *valuesv = dbd_st_FETCH(sth, keysv);
	if (!valuesv)
	valuesv = DBIS->get_attr(sth, keysv);
	ST(0) = valuesv;    /* dbd_st_FETCH did sv_2mortal  */

void
finish(sth)
	SV *        sth
	CODE:
	D_imp_sth(sth);
	D_imp_dbh_from_sth;
	if (!DBIc_ACTIVE(imp_dbh))
	{
		/* Either an explicit disconnect() or global destruction        */
		/* has disconnected us from the database. Finish is meaningless */
		/* XXX warn */
		XSRETURN_YES;
	}
	if (!DBIc_ACTIVE(imp_sth))
	{
		/* No active statement to finish        */
		XSRETURN_YES;
	}
	ST(0) = dbd_st_finish(sth) ? &sv_yes : &sv_no;

void
DESTROY(sth)
	SV *        sth
	PPCODE:
	D_imp_sth(sth);
	ST(0) = &sv_yes;
	if (!DBIc_IMPSET(imp_sth))
	{        /* was never fully set up       */
		if (DBIc_WARN(imp_sth) && !dirty && dbis->debug >= 2)
			warn("Statement handle %s DESTROY ignored - never set up",
				SvPV(sth,na));
	}
	else
	{
		if (DBIc_ACTIVE(imp_sth))
			dbd_st_finish(sth);
		dbd_st_destroy(sth);
	}

# end of Informix.xs
