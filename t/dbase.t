#!/usr/bin/perl -w
#
# @(#)dbase.t	51.2 97/02/26 11:59:55
#
# Copyright (C) 1997 Jonathan Leffler (johnl@informix.com)
#
# Test database creation
# Note that database statements cannot be used with an explicit connection
# with ESQL/C 6.0x and up.

use DBD::InformixTest qw(stmt_ok stmt_fail stmt_note all_ok);

$dbname = "dbd_ix_db";

stmt_note("1..10\n");

stmt_fail unless ($dbh = DBI->connect('','','','Informix'));
stmt_ok;

# Don't care about non-existent database
$dbh->{AutoErrorReport} = 0;
$dbh->do("drop database $dbname");

$dbh->{AutoErrorReport} = 1;
stmt_fail unless ($dbh->do("create database $dbname"));
stmt_ok;
stmt_fail unless ($dbh->do("close database"));
stmt_ok;
stmt_fail unless ($dbh->do("drop database $dbname"));
stmt_ok;
stmt_fail unless ($dbh->disconnect);
stmt_ok;

undef $dbh;

stmt_fail unless ($dbh = DBI->connect('.DEFAULT.','','','Informix'));
stmt_ok;

$dbh->{AutoErrorReport} = 1;
stmt_fail unless ($dbh->do("create database $dbname"));
stmt_ok;
stmt_fail unless ($dbh->do("close database"));
stmt_ok;
stmt_fail unless ($dbh->do("drop database $dbname"));
stmt_ok;
stmt_fail unless ($dbh->disconnect);
stmt_ok;

&all_ok();
