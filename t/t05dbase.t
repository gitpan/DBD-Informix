#!/usr/bin/perl -w
#
#	@(#)$Id: t05dbase.t,v 100.4 2002/02/08 22:50:34 jleffler Exp $ 
#
#	Test database creation and default connections.
#
#	Copyright 1997,1999 Jonathan Leffler
#	Copyright 2000      Informix Software Inc
#	Copyright 2002      IBM
#
# Note that database statements cannot be used with an explicit connection
# with ESQL/C 6.0x and up.

use DBD::Informix::TestHarness;

my ($dbname) = "dbd_ix_db";
my ($user) = $ENV{DBD_INFORMIX_USERNAME};
my ($pass) = $ENV{DBD_INFORMIX_PASSWORD};

stmt_note("1..19\n");

# Do not want these defaults to affect testing (in this file only).
delete $ENV{DBI_DSN};
delete $ENV{DBI_DBNAME};

&stmt_note("# Test (implicit default, old-style) DBI->connect('',...)\n");
stmt_fail unless ($dbh = DBI->connect('',$user,$pass,'Informix'));
stmt_ok;

# Don't care about non-existent database
$dbh->{PrintError} = 0;
$dbh->do("drop database $dbname");

$selver = "SELECT TabName, Owner FROM 'informix'.SysTables WHERE TabName = ' VERSION'";

$dbh->{PrintError} = 1;
&stmt_test($dbh, "create database $dbname");
&select_some_data($dbh, 1, $selver);
&stmt_test($dbh, "close database");
&stmt_test($dbh, "drop database $dbname");
stmt_fail unless ($dbh->disconnect);
stmt_ok;

undef $dbh;

&stmt_note("# Test (explicit default) DBI->connect('.DEFAULT.',...)\n");
stmt_fail unless ($dbh = DBI->connect('.DEFAULT.',$user,$pass,'Informix'));
stmt_ok;

$dbh->{PrintError} = 1;
&stmt_test($dbh, "create database $dbname");
&select_some_data($dbh, 1, $selver);
&stmt_test($dbh, "close database");
&stmt_test($dbh, "drop database $dbname");
stmt_fail unless ($dbh->disconnect);
stmt_ok;

# Test disconnecting implicit connections (B42204)
&stmt_note("# Test (explicit default) DBI->connect('.DEFAULT.',...)\n");
stmt_fail unless ($dbh = DBI->connect('.DEFAULT.',$user,$pass,'Informix'));
stmt_ok;
$dbh->{PrintError} = 1;
&stmt_test($dbh, "create database $dbname");
&select_some_data($dbh, 1, $selver);
&stmt_note("# Test disconnect on DEFAULT connection\n");
stmt_fail unless ($dbh->disconnect);
stmt_ok;

# Clean up test database
&stmt_note("# Clean up test database\n");
stmt_fail unless ($dbh = DBI->connect('.DEFAULT.',$user,$pass,'Informix'));
stmt_ok;
&stmt_test($dbh, "drop database $dbname");
stmt_fail unless ($dbh->disconnect);
stmt_ok;

&all_ok();
