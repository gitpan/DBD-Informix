#!/usr/bin/perl -w
#
#	@(#)$Id: dratt01.t,v 54.1 1997/05/13 15:38:37 johnl Exp $ 
#
#	Driver Attribute test script for DBD::Informix
#
#	Copyright (C) 1997 Jonathan Leffler

use DBD::InformixTest;

&stmt_note("1..3\n");

# Test install...
&stmt_note("# Testing: DBI->install_driver('Informix')\n");
$drh = DBI->install_driver('Informix');
&stmt_ok(0);

print "# DBI Information\n";
print "#     Version:               $DBI::VERSION\n";
print "# Driver Information\n";
print "#     Type:                  $drh->{Type}\n";
print "#     Name:                  $drh->{Name}\n";
print "#     Version:               $drh->{Version}\n";
print "#     Attribution:           $drh->{Attribution}\n";
print "#     Product:               $drh->{ix_ProductName}\n";
print "#     Product Version:       $drh->{ix_ProductVersion}\n";
print "#     Multiple Connections:  $drh->{ix_MultipleConnections}\n";
print "#     Active Connections:    $drh->{ix_ActiveConnections}\n";
print "#     Current Connection:    $drh->{ix_CurrentConnection}\n";
print "# \n";

$dbh = &connect_to_test_database();
&stmt_ok(0);
$dbname = $dbh->{Name};

print "#     Multiple Connections:  $drh->{ix_MultipleConnections}\n";
print "#     Active Connections:    $drh->{ix_ActiveConnections}\n";
print "#     Current Connection:    $drh->{ix_CurrentConnection}\n";
print "#     Current Database:      $dbname\n";

&stmt_note("# Testing: \$dbh->disconnect()\n");
&stmt_fail() unless ($dbh->disconnect);
&stmt_ok();

print "#     Multiple Connections:  $drh->{ix_MultipleConnections}\n";
print "#     Active Connections:    $drh->{ix_ActiveConnections}\n";
print "#     Current Connection:    $drh->{ix_CurrentConnection}\n";

&all_ok;
