#!/usr/bin/perl -w
#
#   @(#)$Id: t10sqlca.t,v 2003.4 2003/03/03 19:18:47 jleffler Exp $
#
#   Test SQLCA Record Handling for DBD::Informix
#
#   Copyright 1997,1999 Jonathan Leffler
#   Copyright 2000      Informix Software Inc
#   Copyright 2002-03   IBM

use DBD::Informix::TestHarness;
use strict;

# Set date format to ISO 8601.
$ENV{DBDATE} = "Y4MD-";

# Test install...
my $dbh = &connect_to_test_database();
print_sqlca($dbh);

&stmt_note("1..9\n");
&stmt_ok();
my $table = "dbd_ix_sqlca";

# Create table for testing
stmt_test $dbh, qq{
CREATE TEMP TABLE $table
(
	Col01	SERIAL(1000) NOT NULL,
	Col02	CHAR(20) NOT NULL,
	Col03	DATE NOT NULL,
	Col04	DATETIME YEAR TO FRACTION(5) NOT NULL,
	Col05   DECIMAL(10,9) NOT NULL
)
};
print_sqlca($dbh);

#my $date = date_as_string($dbh);
my $date = '2002-12-31';
my $pi = '3.141592654';
my $time = "$date 00:00:00.00000";

stmt_test $dbh, qq{
INSERT INTO $table VALUES(0, 'Some Value', '$date', '$time', $pi)
};

print_sqlca($dbh);
stmt_fail "Incorrect SERIAL value" unless $dbh->{ix_sqlerrd}[1] == 1000;

my $select = "SELECT * FROM $table";
my $sth1 = $dbh->prepare($select) or stmt_fail "# failed to prepare $select\n";
$sth1->execute or stmt_fail "# failed to execute $select\n";

# Check that there is now one row of data
validate_unordered_unique_data($sth1, 'col01',
	{ 1000 => { 'col01' => 1000,
				'col02' => 'Some Value',
				'col03' => $date,
				'col04' => $time,
				'col05' => $pi } });

# Insert a row of values.
my $sth2 = $dbh->prepare("INSERT INTO $table VALUES(0, ?, ?, ?, ?)");
&stmt_fail() unless $sth2;
&stmt_ok;
print_sqlca $sth2;
my $date2 = date_as_string($dbh, 12, 31, 9999);
my $e = '2.718281828';
my $time2 = '1997-02-28 00:11:22.55555';
&stmt_fail() unless $sth2->execute('Another value', $date2, $time2, $e);
&stmt_ok;
print_sqlca $sth2;
stmt_fail "Incorrect SERIAL value" unless $dbh->{ix_sqlerrd}[1] == 1001;

# Check that there are now two rows of data
$sth1->execute or stmt_fail "# failed to execute $select\n";
validate_unordered_unique_data($sth1, 'col01',
	{ 1000 => { 'col01' => 1000,
				'col02' => 'Some Value',
				'col03' => $date,
				'col04' => $time,
				'col05' => $pi },
	  1001 => { 'col01' => 1001,
				'col02' => 'Another value',
				'col03' => $date2,
				'col04' => $time2,
				'col05' => $e },
	});

$dbh->disconnect ? stmt_ok : stmt_nok;

&all_ok();
