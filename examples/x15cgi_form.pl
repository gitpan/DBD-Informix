#!/usr/bin/perl -w
#
# @(#)$Id: examples/x15cgi_form.pl version /main/3 1999-05-14 00:33:09 $
#
# Slightly more sophisticated post-processing example CGI script

# load standard Perl modules
use strict;
use DBI;
use Apache;
use CGI::Apache;
use CGI::Carp;

# Run the rest of the script in a block so there are no globals.
# Globals are shared across scripts in mod_perl.
{

    # the environment variables were set in the Apache configuration
    # file rather than here

    # instantiate a CGI object
    my $q = new CGI::Apache;
    my $clear = $q->param('reset') ? 1 : 0;

    # CGI::Apache doesn't support a suitable delete_all or Delete_all...
    map { $q->delete($_); } $q->param if ($clear);

    #  output the http header and html heading
    print
        $q->header(),
        $q->start_html(-title=>'Customer Enquiry'),
        $q->start_form,
        $q->h1({-align=>'CENTER'}, 'Customer Enquiry'),
        $q->hr;

    # connect to the database, instantiating a database handler
    # and activating an automatic exit and notification on errors
    my $dbh = DBI->connect('dbi:Informix:stores', '', '',
                        { 'PrintError'=>1, 'RaiseError'=>1 })
            or die "Could not connect, stopped\n";

    # Generate a hash of state names in USA and abbreviations from State
    # table in database.  Note that HTML ignores the leading space on None,
    # but Perl does not, which is extremely convenient.
    my (%states) = (' None' => 'None');
    {
    my $ref = $dbh->selectall_arrayref("SELECT code, sname FROM state");
    foreach (@$ref) { $states{${$_}[0]} = ${$_}[1]; }
    }

    # Create array of state abbreviations from state hash above.
    my (@states) = sort keys %states;

    print   "\nCustomer Surname: ",
            $q->textfield(-name=>'lname', -default=>'', -override=>$clear),
            $q->p,
            "\nCompany Name: ",
            $q->textfield(-name=>'company', -default=>'', -override=>$clear),
            $q->p,
            "\nCity: ",
            $q->textfield(-name=>'city', -default=>'', -override=>$clear),
            $q->p,
            "\nState: ",
            CGI::scrolling_list(-name=>'state', -default=>[' None'],
                            -override=>$clear,
                            -size=>6,
                            -values=>\@states,
                            -labels=>\%states),
                $q->br,
                $q->submit,
                $q->submit(-name=>'reset', -value=>'Clear Form'),
                $q->hr;


    if ($q->param)
    {
        my $q_lname = $q->param('lname');
        my $q_company = $q->param('company');
        my $q_city = $q->param('city');
        my $q_state = $q->param('state');
        my $query = "SELECT * FROM Customer";
        my $pad = " WHERE";
        if (defined $q_state && $q_state ne ' None')
        {
            $_ = $q_state;
            s/(..).*/$1/;
            $query .= "$pad State = '$_'";
            $pad = " AND";
        }
        if (defined $q_company && $q_company !~ /^\s*$/)
        {
            $query .= "$pad Company MATCHES '$q_company'";
            $pad = " AND";
        }
        if (defined $q_lname && $q_lname !~ /^\s*$/)
        {
            $query .= "$pad Lname MATCHES '$q_lname'";
            $pad = " AND";
        }
        if (defined $q_city && $q_city !~ /^\s*$/)
        {
            $query .= "$pad City MATCHES '$q_city'";
            $pad = " AND";
        }
        $query .= ' ORDER BY Lname, Fname, Company, Customer_num';

        print $query, $q->hr;

        # prepare the select statement
        my $sth = $dbh->prepare( $query ) or
                die "Could not prepare $query; stopped";

        # open the cursor
        $sth->execute() or die "Failed to open cursor for SELECT statment\n";

        # bind columns to variables
        my ($customer_num, $fname, $lname, $company);
        my ($address1, $address2, $city, $state, $zipcode, $phone);
        my @cols = ( \$customer_num, \$fname, \$lname, \$company,
            \$address1, \$address2, \$city, \$state, \$zipcode, \$phone );
        $sth->bind_columns(undef, @cols);

        # chop blanks from char columns
        $sth->{ ChopBlanks } = 1;

        # fetch records from the database
        my $count = 0;
        while ( $sth->fetch() ) {
            if ($count++ == 0)
            {
                # Start a table with a row of table header rows.
                # Encode the <table> tag manually rather than calling
                # $q->table() to avoid printing the entire table at once
                print
                    $q->h1({ align=>'center' }, 'Customer Report' ),
                    "\n<TABLE>\n",
                    $q->TR( { '-valign'=>'top' },
                        $q->th( { '-align'=>'left' }, [
                            'Name',
                            'Company',
                            'Address',
                            'Phone'
                        ] )
                    );
            }
            # Convert NULLS into empty strings (Perl-ish aka obscure!)
            map { $$_ = "" unless defined $$_ } @cols;
            my ($name) = "$lname, $fname";
            my ($addr) = "$address1" . (($address2 eq "") ? "" : ", $address2") .
                            ", $city $state $zipcode";
            # print values as table cells
            print
                $q->TR( { '-valign'=>'top' },
                    $q->td( [
                        $name,
                        $company,
                        $addr,
                        $phone
                    ] )
                );
        }

        # close the table
        print "\n</TABLE>\n" if $count > 0;
        print   "\n",
                $q->center($q->font({-color=>"#C04040"}, "No customers selected")),
                "\n"
            if $count == 0;

        # This free statement is not strictly necessary in DBD::Informix
        # 0.60 as cursors are auto-finished when the last row is fetched.
        # It is needed in earlier versions; it does no damage in later ones.
        $sth->finish();

        # disconnect from the server
        $dbh->disconnect();

        print $q->hr;

        sub ordinal
        {
            my($val) = @_;
            my($lst) = $val % 10;
            my(@suffix) = ("th", "st", "nd", "rd");
            $lst = 0 if ($lst > 3 || ($val % 100 >= 11 && $val % 100 <= 13));
            return "${val}$suffix[$lst]";
        }

        my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
        $year += 1900;
        my $month = (qw(January February March April May June
                        July August September October November December))[$mon];
        my $weekday = (qw(Sunday Monday Tuesday Wednesday
                        Thursday Friday Saturday))[$wday];
        my $daynum = ordinal($day);
        print $q->center("Data extracted at: $weekday, $daynum $month $year at $hour:$min:$sec UTC\n");
        print $q->hr;
    }

    print $q->end_form;

    # finish the html page
    print $q->end_html();

}

1; # notify Perl that the script loaded successfully
