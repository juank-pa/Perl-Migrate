package Migrate::Informix::Table;

use parent qw(Migrate::Table);

sub dbspace { Migrate::Config::config->{dbspace}? 'in '.Migrate::Config::config->{dbspace} : undef }

return 1;
