#!/usr/bin/perl -w
#
# @(#)$Id: t/t81orig.t version /main/11 2000-01-27 16:21:51 $ 
#
# (c)1996 Hermetica. Written by Alligator Descartes <descarte@hermetica.com>
#
# Portions Copyright (C) 1996-97,1999 Jonathan Leffler
# Portions Copyright (C) 2000         Informix Software Inc
# Portions Copyright (C) 2002         IBM
#
# Original basic test -- rewritten to use DBD::InformixTest

use DBD::Informix::TestHarness;

print("1..11\n");

$dbh = connect_to_test_database();
&stmt_ok;

print "# Preparing SELECT * from 'informix'.SysTables ***\n";

$cursor = $dbh->prepare("SELECT * FROM 'informix'.SysTables");
&stmt_fail() unless (defined $cursor);
&stmt_ok;

&stmt_fail() unless $cursor->execute;
&stmt_ok;

print "# Selecting data as an array ***\n";

# Do not rely on the number of tables in Systables -- it varies too much!
my $i = 0;
my $j = 0;
while (@row = $cursor->fetchrow)
{
	$i++;
	# Convert nulls (typically found in the dbase, npused, site or locklevel
	# columns) to empty strings.
	for ($j = 0; $j <= $#row; $j++)
	{
		$row[$j] = '' unless defined $row[$j];
	}
    print "# Row: @row\n";
}

&stmt_fail() unless $i > 0;
&stmt_ok;

&stmt_fail() unless $cursor->finish;
&stmt_ok;
undef $cursor;

print "# Preparing SELECT * FROM 'informix'.SysTables WHERE tabname = 'systables' ***\n";

$cursor2 = $dbh->prepare("SELECT tabname, owner FROM 'informix'.SysTables" .
						 " WHERE tabname = 'systables'");
&stmt_fail() unless (defined $cursor2);
&stmt_ok;

&stmt_fail() unless $cursor2->execute;
&stmt_ok;

print "# Selecting data as a list of specified vars ***\n";

$i = 0;
while (($tabname, $owner) = $cursor2->fetchrow)
{
	$i++;
    print "# tabname = $tabname\towner = $owner\n";
}

&stmt_fail() unless $i > 0;
&stmt_ok;

&stmt_fail() unless $cursor2->finish;
&stmt_ok;
undef $cursor2;

&stmt_fail() unless $dbh->do("CREATE TEMP TABLE dbd_ix_pants2 (a INTEGER)");
&stmt_ok;

&stmt_fail() unless $dbh->disconnect;
&stmt_ok;
&all_ok;
