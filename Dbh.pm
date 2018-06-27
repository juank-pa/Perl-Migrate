package Dbh;

use strict;
use warnings;

use Log;
use DBI;

our $_DBH;
our $_DBHLockMode = 'wait';

#our $DBSchema = $ENV{MS_SCHEMA}? qq{"$ENV{MS_SCHEMA}".} : '';
our $DBSchema = '';
our $DBUserName = $ENV{MS_USER} // $ENV{DBI_USER};
our $DBPassword = $ENV{MS_PASS} // $ENV{DBI_PASS};
our $DBDataSource = $ENV{MS_DSN} // $ENV{DBI_DSN};

our $maxDBHAttempts = 5;
our $DBOptions = { RaiseError => 1, AutoCommit => 1, ChopBlanks => 1, ShowErrorStatement => 1 };
our $dbhRetryDelay = 1;
our $_DBHLastUpdated = undef;

sub getDBH
{
    return _getDBHWithRetries($DBDataSource, $DBUserName, $DBPassword);
}

sub doSQL
{
    my $query = shift;
    my $field_hash = shift;
    my $dbh = shift;

    return $dbh->do($query);
}

sub do
{
    my $self = shift;
    my @queries = split(';', shift);
    my $dbh = getDBH();

    foreach (@queries) {
        eval {
            $_ =~ s/^\s+//;
            $_ =~ s/\s+$//;
            $dbh->do($_) if $_;
        }
    }
}

sub runSQL
{
    my $query = shift;
    my $field_hash = shift // {};
    my $dbh = shift;
    my $sth = $dbh->prepare($query);

    if (!$sth->execute(values %$field_hash)) {
        return $dbh->errstr;
    }

    if(wantarray) {
        my @retval;
        while (my $row = $sth->fetchrow_hashref) {
            push @retval, $row;
        }
        return @retval;
    }

    return $sth->fetchrow_hashref;
}

sub query
{
    my $table_name = shift;
    my $field_hash = shift;
    my $query = "select * from " . $table_name;

    if( ref($field_hash) ) {
        $query = "select * from $table_name where ";
        $query .= join " and ", map("$_ = ?", keys %$field_hash);
    }

    return $query;
}

# PRIVATE METHODS ------------

sub _getDBHWithRetries
{
    Log::enter_trace();

    my $datasource  = shift or Log::error_die("No data source");
    my $username    = shift or Log::error_die("No username");
    my $password    = shift or Log::error_die("No password");

    my $lock_attr = 'private_lockmode';
    my $found_cached = 0;

    # This will be the dbh we return, assuming everything is copacetic.
    my $dbh = undef;

    if( ref $_DBH && defined $_DBH->{$lock_attr} && ($_DBH->{$lock_attr} eq $_DBHLockMode) ) {
        $dbh = $_DBH;
        $found_cached = 1;
    }

    # Try to connect
    eval {
        $dbh = DBI->connect($datasource, $username, $password, $DBOptions)
            or Log::error_die("Could not connect to database: $!\n");
    };
    if($@) {
        warn("Error trying to connect to database : ($DBI::errstr) : \$\@ : $@");
    }

    # If we have still failed to connect to the db, well, that's pretty bad.
    if(!$dbh || !ref($dbh)) {
        Log::error_die("Could not connect to database ($datasource)");
    }

    $_DBH = $dbh;
    $_DBHLastUpdated = time;

    Log::exit_trace();
    return $dbh;
}

 return 1;
