/*
 * @(#)$Id: dbdattr.ec,v 60.1 1998/07/30 04:03:22 jleffler Exp $ 
 *
 * DBD::Informix for Perl Version 5 -- attribute handling
 *
 * Copyright (c) 1997-98 Jonathan Leffler
 *
 * You may distribute under the terms of either the GNU General Public
 * License or the Artistic License, as specified in the Perl README file.
 */

/*TABSTOP=4*/

#ifndef lint
static const char rcs[] = "@(#)$Id: dbdattr.ec,v 60.1 1998/07/30 04:03:22 jleffler Exp $";
#endif

#include <stdio.h>
#include <string.h>

#include "Informix.h"

/*
** Check whether key defined by key length (kl) and key value (kv)
** matches keyword (kw), which should be a character literal ("KeyWord")!
*/
#define KEY_MATCH(kl, kv, kw) ((kl) == (sizeof(kw) - 1) && strEQ((kv), (kw)))

static const char esql_prodname[] = ESQLC_VERSION_STRING;
static const int  esql_prodvrsn   = ESQLC_VERSION;

#ifdef USE_DEPRECATED
/* Print message deprecating old feature and indicating new */
static void dbd_ix_deprecate(const char *old)
{
	croak("%s - do not use deprecated attribute name %s (use 'ix_' prefix)\n",
		 dbd_ix_module(), old);
}
#endif /* USE_DEPRECATED */

/* Convert string into BlobLocn value */
static BlobLocn blob_bindtype(SV *valuesv)
{
	STRLEN vlen;
	char *value = SvPV(valuesv, vlen);
	BlobLocn locn = BLOB_DEFAULT;

	if (KEY_MATCH(vlen, value, "InMemory"))
		locn = BLOB_IN_MEMORY;
	else if (KEY_MATCH(vlen, value, "InFile"))
		locn = BLOB_IN_NAMEFILE;
	else
		locn = BLOB_DEFAULT;
	return(locn);
}

/* Convert string into BlobLocn value */
static char *blob_bindname(BlobLocn locn)
{
	char *value = 0;

	switch (locn)
	{
	case BLOB_IN_MEMORY:
		value =  "InMemory";
		break;
	case BLOB_IN_NAMEFILE:
		value = "InFile";
		break;
	default:
		value = "Default";
		break;
	}
	return(value);
}

SV *dbd_ix_dr_FETCH_attrib(imp_drh_t *imp_drh, SV *keysv)
{
	STRLEN          kl;
	char           *key = SvPV(keysv, kl);
	SV             *retsv = Nullsv;

	dbd_ix_debug(1, "%s::dbd_dr_FETCH_attrib()\n", dbd_ix_module());

	if (KEY_MATCH(kl, key, "ix_MultipleConnections"))
	{
		retsv = newSViv((IV)imp_drh->multipleconnections);
	}
	else if (KEY_MATCH(kl, key, "ix_ActiveConnections"))
	{
		retsv = newSViv((IV)imp_drh->n_connections);
	}
	else if (KEY_MATCH(kl, key, "ix_CurrentConnection"))
	{
		char *conn = (char *)imp_drh->current_connection;	/* const_cast<char*> */
		if (conn == 0)
			conn = "<<no current connection>>";
		retsv = newSVpv(conn, 0);
	}
	else if (KEY_MATCH(kl, key, "ix_ProductVersion"))
	{
		retsv = newSViv((IV)esql_prodvrsn);
	}
	else if (KEY_MATCH(kl, key, "ix_ProductName"))
	{
		retsv = newSVpv((char *)esql_prodname, 0);	/* const_cast<char *> */
	}

	else
		return FALSE;

	return sv_2mortal(retsv);
}

/* Set database connection attributes */
int dbd_ix_db_STORE_attrib(SV *dbh, imp_dbh_t *imp_dbh, SV *keysv, SV *valuesv)
{
	STRLEN          kl;
	char           *key = SvPV(keysv, kl);
	int             newval = SvTRUE(valuesv);
	int             retval = True;

	dbd_ix_debug(1, "Enter %s::dbd_db_STORE_attrib()\n", dbd_ix_module());
	if (KEY_MATCH(kl, key, "AutoCommit"))
	{
		if (imp_dbh->is_loggeddb == False)
		{
			assert(DBI_AutoCommit(imp_dbh));
			if (newval == False)
				dbd_ix_debug(0,
					"%s - Cannot unset AutoCommit for unlogged databases\n",
					dbd_ix_module());
		}
		else
		{
			int oldval = DBI_AutoCommit(imp_dbh);
			DBIc_set(imp_dbh, DBIcf_AutoCommit, newval);
			if (oldval == False && newval == True)
			{
				/* Commit any outstanding changes (it is AutoCommit!) */
				retval = dbd_ix_db_commit(dbh, imp_dbh);
			}
			else if (oldval == True && newval == False)
			{
				/* AutoCommit turned off - start TX in non-ANSI databases */
				if (imp_dbh->is_modeansi == False)
					retval = dbd_ix_db_begin(imp_dbh);
			}
			else
			{
				/* AutoCommit state not changed */
				assert(oldval == newval);
			}
		}
	}
	else if (KEY_MATCH(kl, key, "ix_BlobLocation"))
	{
		imp_dbh->blob_bind = blob_bindtype(valuesv);
	}
	else if (KEY_MATCH(kl, key, "ix_AutoErrorReport"))
	{
		DBIc_set(imp_dbh, DBIcf_PrintError, newval);
	}
	else
	{
		retval = FALSE;
	}

	dbd_ix_debug(1, "Exit %s::dbd_db_STORE_attrib()\n", dbd_ix_module());
	return retval;
}

/* Convert sqlca.sqlerrd into an AV */
static SV *newSqlerrd(const Sqlca *psqlca)
{
	int i;
	AV *av = newAV();
	SV *retsv = newRV((SV *)av);
	av_extend(av, (I32)6);
	sv_2mortal((SV *)av);
	for (i = 0; i < 6; i++)
	{
		av_store(av, i, newSViv((IV)psqlca->sqlerrd[i]));
	}
	return(retsv);
}

/* Convert sqlca.sqlwarn into an AV */
static SV *newSqlwarn(const Sqlca *psqlca)
{
	int i;
	AV             *av = newAV();
	char            warning[2];
	const char     *sqlwarn = &psqlca->sqlwarn.sqlwarn0;
	SV *retsv = newRV((SV *)av);
	av_extend(av, (I32)8);
	sv_2mortal((SV *)av);
	warning[1] = '\0';
	for (i = 0; i < 8; i++)
	{
		warning[0] = *sqlwarn++;
		av_store(av, i, newSVpv(warning, 0));
	}
	return(retsv);
}

static SV *dbd_ix_getsqlca(imp_dbh_t *imp_dbh, STRLEN kl, char *key)
{
	SV *retsv = NULL;

	/* Preferred versions */
	if (KEY_MATCH(kl, key, "ix_sqlcode"))
	{
		retsv = newSViv((IV)imp_dbh->ix_sqlca.sqlcode);
	}
	else if (KEY_MATCH(kl, key, "ix_sqlerrm"))
	{
		retsv = newSVpv(imp_dbh->ix_sqlca.sqlerrm, 0);
	}
	else if (KEY_MATCH(kl, key, "ix_sqlerrp"))
	{
		retsv = newSVpv(imp_dbh->ix_sqlca.sqlerrp, 0);
	}
	else if (KEY_MATCH(kl, key, "ix_sqlerrd"))
	{
		retsv = newSqlerrd(&imp_dbh->ix_sqlca);
	}
	else if (KEY_MATCH(kl, key, "ix_sqlwarn"))
	{
		retsv = newSqlwarn(&imp_dbh->ix_sqlca);
	}

	return(retsv);
}

SV *dbd_ix_db_FETCH_attrib(SV *dbh, imp_dbh_t *imp_dbh, SV *keysv)
{
	STRLEN          kl;
	char           *key = SvPV(keysv, kl);
	SV             *retsv = Nullsv;

	dbd_ix_debug(1, "%s::dbd_db_FETCH_attrib()\n", dbd_ix_module());

	if (KEY_MATCH(kl, key, "AutoCommit"))
	{
		retsv = newSViv((IV)DBI_AutoCommit(imp_dbh));
	}
	else if (KEY_MATCH(kl, key, "ix_InformixOnLine"))
	{
		retsv = newSViv((IV)imp_dbh->is_onlinedb);
	}
	else if (KEY_MATCH(kl, key, "ix_LoggedDatabase"))
	{
		retsv = newSViv((IV)imp_dbh->is_loggeddb);
	}
	else if (KEY_MATCH(kl, key, "ix_InTransaction"))
	{
		retsv = newSViv((IV)imp_dbh->is_txactive);
	}
	else if (KEY_MATCH(kl, key, "ix_ModeAnsiDatabase"))
	{
		retsv = newSViv((IV)imp_dbh->is_modeansi);
	}
	else if (KEY_MATCH(kl, key, "ix_BlobLocation"))
	{
		retsv = newSVpv(blob_bindname(imp_dbh->blob_bind), 0);
	}
	else if (KEY_MATCH(kl, key, "ix_AutoErrorReport"))
	{
		retsv = newSViv((IV)(DBIc_is(imp_dbh, DBIcf_PrintError) != 0));
	}
	else if (KEY_MATCH(kl, key, "ix_ConnectionName"))
	{
		retsv = newSVpv(imp_dbh->nm_connection, 0);
	}
	else if (KEY_MATCH(kl, key, "ix_DatabaseName"))
	{
		char *dbname = "";
		if (imp_dbh->database)
			dbname = SvPV(imp_dbh->database, na);
		retsv = newSVpv(dbname, 0);
	}
	else if ((retsv = dbd_ix_getsqlca(imp_dbh, kl, key)) != NULL)
	{
		/* Nothing to do */
	}

	else
		return FALSE;

	return sv_2mortal(retsv);
}

/* Store statement attributes */
int dbd_ix_st_STORE_attrib(SV *sth, imp_sth_t *imp_sth, SV *keysv, SV *valuesv)
{
	STRLEN          kl;
	char           *key = SvPV(keysv, kl);
	int             rc = TRUE;

	dbd_ix_debug(1, "Enter %s::dbd_st_STORE_attrib()\n", dbd_ix_module());
	if (KEY_MATCH(kl, key, "ix_BlobLocation"))
	{
		imp_sth->blob_bind = blob_bindtype(valuesv);
	}
	else
		rc = FALSE;

	dbd_ix_debug(1, "Exit %s::dbd_st_STORE_attrib()\n", dbd_ix_module());
	return rc;
}

SV *dbd_ix_st_FETCH_attrib(SV *sth, imp_sth_t *imp_sth, SV *keysv)
{
	STRLEN          kl;
	char           *key = SvPV(keysv, kl);
	SV             *retsv = NULL;
	AV             *av = 0;
	EXEC SQL BEGIN DECLARE SECTION;
	char           *nm_obind = imp_sth->nm_obind;
	long			coltype;
	long			collength;
	long			colnull;
	char			colname[NAMESIZE];
	int             i;
	EXEC SQL END DECLARE SECTION;

	dbd_ix_debug(1, "Enter %s::dbd_st_FETCH_attrib()\n", dbd_ix_module());

	/* Standard attributes */
	if (KEY_MATCH(kl, key, "NAME"))
	{
		av = newAV();
		retsv = newRV((SV *)av);
		for (i = 1; i <= imp_sth->n_columns; i++)
		{
			EXEC SQL GET DESCRIPTOR :nm_obind VALUE :i
				:colname = NAME;
			colname[byleng(colname, strlen(colname))] = '\0';
			av_store(av, i - 1, newSVpv(colname, 0));
		}
	}
	else if (KEY_MATCH(kl, key, "NULLABLE"))
	{
		av = newAV();
		retsv = newRV((SV *)av);
		for (i = 1; i <= imp_sth->n_columns; i++)
		{
			EXEC SQL GET DESCRIPTOR :nm_obind VALUE :i
				:colnull = NULLABLE;
			av_store(av, i - 1, newSViv((IV)colnull));
		}
	}
	else if (KEY_MATCH(kl, key, "TYPE"))
	{
		/* Returns ODBC (CLI) type numbers. */
		av = newAV();
		retsv = newRV((SV *)av);
		for (i = 1; i <= imp_sth->n_columns; i++)
		{
			SV		*sv;
			EXEC SQL GET DESCRIPTOR :nm_obind VALUE :i
				:coltype = TYPE, :collength = LENGTH;
			sv = newSViv(map_type_ifmx_to_odbc(coltype, collength));
			av_store(av, i - 1, sv);
		}
	}
	else if (KEY_MATCH(kl, key, "PRECISION"))
	{
		/* Should return CLI precision numbers. */
		av = newAV();
		retsv = newRV((SV *)av);
		for (i = 1; i <= imp_sth->n_columns; i++)
		{
			SV		*sv;
			EXEC SQL GET DESCRIPTOR :nm_obind VALUE :i
				:coltype = TYPE, :collength = LENGTH;
			sv = newSViv(map_prec_ifmx_to_odbc(coltype, collength));
			av_store(av, i - 1, sv);
		}
	}
	else if (KEY_MATCH(kl, key, "SCALE"))
	{
		/* Should return CLI scale numbers. */
		av = newAV();
		retsv = newRV((SV *)av);
		for (i = 1; i <= imp_sth->n_columns; i++)
		{
			SV		*sv;
			EXEC SQL GET DESCRIPTOR :nm_obind VALUE :i
				:coltype = TYPE, :collength = LENGTH;
			sv = newSViv(map_scale_ifmx_to_odbc(coltype, collength));
			av_store(av, i - 1, sv);
		}
	}
	else if (KEY_MATCH(kl, key, "NUM_OF_PARAMS"))
	{
		retsv = newSViv((IV)DBIc_NUM_PARAMS(imp_sth));
	}
	else if (KEY_MATCH(kl, key, "NUM_OF_FIELDS"))
	{
		assert(imp_sth->n_columns == DBIc_NUM_FIELDS(imp_sth));
		retsv = newSViv((IV)imp_sth->n_columns);
	}
	else if (KEY_MATCH(kl, key, "CursorName"))
	{
		retsv = newSVpv(imp_sth->nm_cursor, 0);
	}

	/* Informix specific attributes */
	else if (KEY_MATCH(kl, key, "ix_NativeTypeNames"))
	{
		char buffer[SQLTYPENAME_BUFSIZ];
		SV		*sv;
		av = newAV();
		retsv = newRV((SV *)av);
		for (i = 1; i <= imp_sth->n_columns; i++)
		{
			EXEC SQL GET DESCRIPTOR :nm_obind VALUE :i
				:coltype = TYPE, :collength = LENGTH;
			sv = newSVpv(sqltypename(coltype, collength, buffer), 0);
			av_store(av, i - 1, sv);
		}
	}
	else if (KEY_MATCH(kl, key, "ix_Fetchable"))
	{
		Boolean rv = ((imp_sth->st_type == SQ_SELECT) ||
						(imp_sth->st_type == SQ_EXECPROC && imp_sth->n_columns > 0));
		retsv = newSViv((IV)rv);
	}
	else if (KEY_MATCH(kl, key, "ix_BlobLocation"))
	{
		retsv = newSVpv(blob_bindname(imp_sth->dbh->blob_bind), 0);
	}
	else if ((retsv = dbd_ix_getsqlca(imp_sth->dbh, kl, key)) != NULL)
	{
		/* Nothing specific to do */
	}
	else if (KEY_MATCH(kl, key, "ix_ColType"))
	{
		av = newAV();
		retsv = newRV((SV *)av);
		for (i = 1; i <= imp_sth->n_columns; i++)
		{
			EXEC SQL GET DESCRIPTOR :nm_obind VALUE :i
				:coltype = TYPE;
			av_store(av, i - 1, newSViv((IV)coltype));
		}
	}
	else if (KEY_MATCH(kl, key, "ix_ColLength"))
	{
		av = newAV();
		retsv = newRV((SV *)av);
		for (i = 1; i <= imp_sth->n_columns; i++)
		{
			EXEC SQL GET DESCRIPTOR :nm_obind VALUE :i
				:collength = LENGTH;
			av_store(av, i - 1, newSViv((IV)collength));
		}
	}
	else if (KEY_MATCH(kl, key, "ix_StatementText"))
	{
		char *text = "";
		if (imp_sth->st_text)
			text = SvPV(imp_sth->st_text, na);
		retsv = newSVpv(text, 0);
	}
	else
	{
		return Nullsv;
	}

	dbd_ix_debug(1, "Exit %s::dbd_st_FETCH_attrib\n", dbd_ix_module());

	if (av != 0)
		sv_2mortal((SV *)av);

	return sv_2mortal(retsv);
}

