#!/usr/bin/perl -w
#
#	@(#)$Id: t91udts.t,v 100.9 2002/11/19 17:32:42 jleffler Exp $
#
#	Test basic handling of user-defined data types
#
#	Copyright 2000 Informix Software Inc
#	Copyright 2002 IBM

use strict;
use DBD::Informix::TestHarness;

my ($dbh) = &test_for_ius;

$dbh->{ChopBlanks} = 1;

&stmt_note("1..16\n");

my ($noslobs) = $ENV{DBD_INFORMIX_NO_SBSPACE};

my ($sbspace) = $ENV{DBD_INFORMIX_SBSPACE};
$sbspace = "sbspace" unless $sbspace;

sub do_stmt
{
	my($dbh,$stmt) = @_;
	print "# $stmt\n";
	$dbh->do($stmt) or stmt_err;
}

# Drop any pre-existing versions of any of these test types
$dbh->{PrintError} = 0;
do_stmt $dbh, "drop table dbd_ix_udts";
do_stmt $dbh, "drop type dbd_ix_distofi8 restrict";
do_stmt $dbh, "drop type dbd_ix_distofbool restrict";
do_stmt $dbh, "drop type dbd_ix_distoflvc restrict";
do_stmt $dbh, "drop type dbd_ix_distofnamed restrict";
do_stmt $dbh, "drop row type dbd_ix_udts_named restrict";
$dbh->{PrintError} = 1;

# Create the types and table
stmt_test $dbh, 'create row type dbd_ix_udts_named (i int)';

stmt_test $dbh, "create distinct type dbd_ix_distofi8 as int8";
stmt_test $dbh, "create distinct type dbd_ix_distofbool as boolean";
stmt_test $dbh, "create distinct type dbd_ix_distoflvc as lvarchar";
stmt_test $dbh, "create distinct type dbd_ix_distofnamed as dbd_ix_udts_named";

my ($stmt) = qq%
     create table dbd_ix_udts
     (s8 serial8,
      i8 int8,
      b boolean,
      lvc lvarchar,
      unnamed row(i int, l lvarchar),
      named dbd_ix_udts_named,
      sint set(int not null),
      lunnamed list(row(i int, c char(10)) not null),
      mnamed multiset(dbd_ix_udts_named not null),
      di8 dbd_ix_distofi8,
      db dbd_ix_distofbool,
      dlvc dbd_ix_distoflvc,
      dnamed dbd_ix_distofnamed%;
$stmt .= ($noslobs) ? ")" : ", cl clob) put cl in ($sbspace)";
stmt_test $dbh, $stmt;

# Insert some data into the table.  NB: $0 refers to this script file!
my ($longstr) = "1234567890" x 30;
my ($slobval) = ($noslobs) ? "" : ", filetoclob('$0', 'client')";
stmt_test $dbh,
    qq%
     insert into dbd_ix_udts values
     (1, 1, 't', '$longstr', row(1, '$longstr'), row(1)::dbd_ix_udts_named,
      set{1, 10, 100}, list{row(1, 'one')}, multiset{row(1)::dbd_ix_udts_named},
      '1', 't', '$longstr', row(1)::dbd_ix_distofnamed $slobval)
     %;

# Check that fetch truncates udts longer than 256 (rather than blowing up)
my ($inserted) = 1;
$slobval = ($noslobs) ? "" : ", filetoclob(?, 'client')";
my ($ins) = qq%
     insert into dbd_ix_udts values
     (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? $slobval)
     %;
$ins =~ s/\s+/ /gm;
stmt_note("# PREPARE: $ins\n");
my ($sth) = $dbh->prepare($ins)
    or stmt_fail;
stmt_ok;

# Check inserting nulls...
my ($null);
undef $null;
# This is lazy - there has to be a better way!
if ($noslobs)
{
	$sth->execute
		(2, $null, $null, $null, $null, $null, $null,
		  $null, $null, $null, $null, $null, $null)
		or stmt_fail;
}
else
{
	$sth->execute
		(2, $null, $null, $null, $null, $null, $null,
		  $null, $null, $null, $null, $null, $null, $null)
		or stmt_fail;
}
stmt_ok;
stmt_note "# inserted nulls OK\n";

$inserted += $sth->rows;
stmt_fail unless $inserted == 2;

# if the length of udt is longer than 256 and truncated value is
# syntactically wrong (ex. row(3, '$longstr')), insert will fail and
# report invalid syntax (rather than blow up).  NB: $0 refers to this
# script file!
# This is lazy - there has to be a better way!
if ($noslobs)
{
	$sth->execute
		(3, 3, "f", "$longstr", "row(3, 'three')", "row(3)", "set{3, 30, 300}",
		 "list{row(3, 'three'), row(30, 'thirty')}",
		 "multiset{row(3), row(30)}", "3", "f", "$longstr", "row(3)")
		or die;
}
else
{
	$sth->execute
		(3, 3, "f", "$longstr", "row(3, 'three')", "row(3)", "set{3, 30, 300}",
		 "list{row(3, 'three'), row(30, 'thirty')}",
		 "multiset{row(3), row(30)}", "3", "f", "$longstr", "row(3)", "$0")
		or die;
}
$inserted += $sth->rows;
$sth->finish;
stmt_note "# inserted $inserted \n";

# Record basename of extracted file names...
my ($filename) = "dbd_ix_udts.pl";
my ($fetched) = 0;
$slobval = ($noslobs) ? "" : ", lotofile(cl, '$filename', 'client')";
my ($sel) = qq%
     select s8, i8, b, lvc, unnamed, named, sint, lunnamed, mnamed, di8,
     db, dlvc, dnamed $slobval
     from dbd_ix_udts
     %;
$sel =~ s/\s+/ /gm;
stmt_note "# PREPARE: $sel\n";
$sth = $dbh->prepare($sel)
    or stmt_fail;
$sth->execute
	or stmt_fail;
stmt_ok;

my ($results) = $sth->fetchall_arrayref;
my ($row);
foreach $row (@$results) {
    $fetched++;
	grep { $_ = "." if !defined $_; } @$row;
    print "# ROW-$fetched: @$row\n";
}
$sth->finish;
# Need to verify fetched data
stmt_note "# fetched $fetched \n";

$slobval = ($noslobs) ? "" : ", cl = filetoclob(?, 'client')"; 
my ($upd) = qq%
     update dbd_ix_udts set i8 = ?, b = ?, lvc = ?, unnamed = ?, named = ?,
         sint = ?, lunnamed = ?, mnamed = ?, di8 = ?, db = ?, dlvc = ?,
         dnamed = ? $slobval
     where s8 = ? and i8 = ? and b = ? and lvc = ?
         and named = ? and sint = ? and lunnamed = ?
         and mnamed = ? and di8::int8 = ? and db::boolean = ?
         and dlvc::lvarchar = ? and dnamed = ?
     %;
$upd =~ s/\s+/ /gm;
stmt_note "# PREPARE: $upd\n";
$sth = $dbh->prepare($upd)
    or stmt_fail;
stmt_ok;

stmt_note "# EXECUTE\n";
# This is lazy - there has to be a better way!
if ($noslobs)
{
	$sth->execute
		 (10, "f", "$longstr", "row(10, 'ten')", "row(10)",
		  "set{10000, 100000, 1000000}", "list{row(10, 'ten')}",
		  "multiset{row(10)}", "10", "f", "$longstr", "row(10)",
		  1, 1, "t", "$longstr", "row(1)", "set{1, 10, 100}",
		  "list{row(1, 'one')}", "multiset{row(1)}", "1", "t",
		  "$longstr", "row(1)")
		or stmt_fail;
}
else
{
	$sth->execute
		 (10, "f", "$longstr", "row(10, 'ten')", "row(10)",
		  "set{10000, 100000, 1000000}", "list{row(10, 'ten')}",
		  "multiset{row(10)}", "10", "f", "$longstr", "row(10)", "$0",
		  1, 1, "t", "$longstr", "row(1)", "set{1, 10, 100}",
		  "list{row(1, 'one')}", "multiset{row(1)}", "1", "t",
		  "$longstr", "row(1)")
		or stmt_fail;
}
my ($nrows) = $sth->rows;
stmt_note "# updated $nrows \n";
stmt_ok;

my ($del) = qq%
     delete from dbd_ix_udts where s8 = ? and i8 = ? and b = ? and lvc = ?
         and unnamed = ? and named = ? and sint = ? and lunnamed = ?
         and mnamed = ? and di8::int8 = ? and db::boolean = ?
         and dlvc::lvarchar = ? and dnamed = ?
     %;
$del =~ s/\s+/ /gm;
stmt_note "# PREPARE: $del\n";
$sth = $dbh->prepare($del)
    or stmt_fail;
stmt_ok;

stmt_note "# EXECUTE\n";
$sth->execute
    (3, 3, "f", "$longstr", "row(3, 'three')", "row(3)", "set{3, 30, 300}",
     "list{row(3, 'three'), row(30, 'thirty')}",
     "multiset{row(3), row(30)}", "3", "f", "$longstr", "row(3)")
    or stmt_fail;
stmt_ok;
$nrows = $sth->rows;
stmt_note "# deleted $nrows\n";

# Drop new versions of any of these test types
$dbh->do("drop table dbd_ix_udts");
$dbh->do("drop type dbd_ix_distofi8 restrict");
$dbh->do("drop type dbd_ix_distofbool restrict");
$dbh->do("drop type dbd_ix_distoflvc restrict");
$dbh->do("drop type dbd_ix_distofnamed restrict");
$dbh->do("drop row type dbd_ix_udts_named restrict");
stmt_ok;

$dbh->disconnect or die;
stmt_ok;

# Remove the files created by LOTOFILE.
unlink <$filename.*> unless $noslobs;

all_ok;
