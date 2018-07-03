package Migrate::Dbh;

use strict;
use warnings;

BEGIN {
    use Exporter;
    our ($VERSION, @ISA, @EXPORT_OK);

    $VERSION = 0.001;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(get_dbh);
}

use DBI;
use Migrate::Config;

our $_DBH;
our $DefaultOptions = { RaiseError => 1, AutoCommit => 1, ChopBlanks => 1, ShowErrorStatement => 1 };

sub dbh_attr {
    my $attr  = Migrate::Config::config->{attr};
    return \(%$DefaultOptions, %$attr);
}

sub get_dbh
{
    return $_DBH if ref $_DBH;

    my $dbh = undef;
    my $config = Migrate::Config::config;
    my $attr  = dbh_attr;

    eval {
        $dbh = DBI->connect($config->{dsn}, $config->{username}, $config->{password}, $attr)
            or die("Could not connect to database: $!\n");

    };
    if($@) {
        warn("Error trying to connect to database : ($DBI::errstr) : \$\@ : $@");
    }

    $dbh and ref $dbh or die("Could not connect to database ($config->{dsn})");

    $attr->{on_connect}->($dbh) if $attr->{on_connect};

    return $_DBH = $dbh;
}

sub _setup_tables {
    my $dbh = shift;
    $dbh->do($_) foreach Migrate::Handler->create_migrations_table_query;
}

return 1;