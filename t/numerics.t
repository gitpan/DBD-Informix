#!/usr/bin/perl -w
#
# @(#)numerics.t	25.2 96/12/04 14:06:56
#
# (c)1996 Hermetica. Written by Alligator Descartes <descarte@hermetica.com>
#
# Basic Numeric type testing

$tablename = "test3";

use DBD::InformixTest;

print("1..10\n");
$dbh = connect_to_test_database();
&stmt_ok;

$stmt1 = qq{
CREATE TEMP TABLE $tablename
(
	id1     INTEGER,
	id2     SMALLINT,
	id3     FLOAT,
	id4     DECIMAL,
	name    CHAR(64)
)
};
$stmt1 =~ s/\s+/ /gm;
&stmt_test($dbh, $stmt1, 0);

&stmt_test($dbh, "INSERT INTO $tablename VALUES(1122, " .
				 "-234, -3.1415926, 3.7655, 'Hortense HorseRadish')");
&stmt_test($dbh, "INSERT INTO $tablename VALUES(1001002002, " .
				 "+342, -3141.5926, 3.7655e25, 'Arbuthnot Artichoke')");

$stmt2 = "SELECT id1, id2, id3, id4, name FROM $tablename";
&stmt_note("# Testing: prepare('$stmt2')\n");
$sth = $dbh->prepare("SELECT id1, id2, id3, id4, name FROM $tablename");
&stmt_fail() unless (defined $sth);
&stmt_ok(0);

&stmt_fail() unless $sth->execute;
&stmt_ok(0);

while (($id1, $id2, $id3, $id4, $name) = $sth->fetchrow)
{
	&stmt_ok(0);
    &stmt_note("# Row: $id1\t$id2\t$id3\t$id4\t$name\n");
}

&stmt_fail() unless $sth->finish;
&stmt_ok(0);
undef $sth;

&stmt_fail() unless $dbh->disconnect;
&stmt_ok(0);
&all_ok();
