package Migrate::Informix::Constraint::Null;

use strict;
use warnings;

use parent qw(Migrate::Constraint::Null);

sub add_constraint { my $self = shift; push(@_, $self->constraint_sql); @_ }

return 1;