#!/usr/bin/perl -w
#
#	@(#)$Id: t72blob.t,v 60.1 1998/05/19 20:36:07 jleffler Exp $ 
#
#	Test Basic Blobs (INSERT) for DBD::Informix
#
#	Copyright (C) 1996,1997 Jonathan Leffler

use DBD::InformixTest;

# Test install...
$dbh = connect_to_test_database(1);

if (!$dbh->{ix_InformixOnLine})
{
	print("1..2\n");
	&stmt_note("# Not Informix-OnLine -- no blob testing\n");
	&stmt_ok(0);
}
else
{
	print("1..9\n");
	&stmt_ok(0);

	$dbh->{ix_AutoErrorReport} = 0;
	$stmt1 = 'DROP TABLE Dbd_IX_BlobTest';
	$dbh->do($stmt1);
	# Fail unless table dropped or table not found (-206).
	# Problem found by Nuno Carneiro de Moura <ncmoura@net.mailcom.pt>
	$sqlcode = $dbh->{ix_sqlcode};
	&stmt_fail() unless ($sqlcode == 0 || $sqlcode == -206);
	&stmt_ok(0);
	$stmt2 = 'CREATE TABLE Dbd_IX_BlobTest (I SERIAL UNIQUE, ' .
			 ' T TEXT IN TABLE, B BYTE IN TABLE)';
	&stmt_test($dbh, $stmt2, 0);

	$stmt3 = 'INSERT INTO Dbd_IX_BlobTest VALUES(?, ?, ?)';
	&stmt_note("# Testing: \$insert = \$dbh->prepare('$stmt3')\n");
	&stmt_fail() unless ($insert = $dbh->prepare($stmt3));
	&stmt_ok(0);

	$blob1 = "This is a TEXT blob";
	$blob2 = "This is a pseudo-BYTE blob";
	&stmt_note("# Testing: \$insert->execute(1, \$blob1, \$blob2)\n");
	&stmt_fail() unless ($insert->execute(1, $blob1, $blob2));
	&stmt_ok(0);

	# At one time, we got free problems reported when we did this!
	$blob1 = "This is also a TEXT blob";
	$blob2 = "This is also a pseudo-BYTE blob";
	&stmt_note("# Testing: \$insert->execute(2, \$blob1, \$blob2)\n");
	&stmt_fail() unless ($insert->execute(2, $blob1, $blob2));
	&stmt_ok(0);

	$blob3 = "This, too, is a TEXT blob";
	$blob4 = "This, too, is a pseudo-BYTE blob";
	&stmt_note("# Testing: \$insert->execute(3, \$blob3, \$blob4)\n");
	&stmt_fail() unless ($insert->execute(3, $blob3, $blob4));
	&stmt_ok(0);

	&stmt_note("Testing: \$insert->finish\n");
	&stmt_fail() unless ($insert->finish);
	&stmt_ok(0);

	$dbh->commit if ($dbh->{ix_InTransaction});
}

&stmt_note("# Testing: \$dbh->disconnect()\n");
&stmt_fail() unless ($dbh->disconnect);
&stmt_ok(0);

&all_ok();