package Linux::Perl::Base::Fileno;

use strict;
use warnings;

=head1 METHODS

=head2 I<OBJ>->fileno()

Returns the file descriptor number.

=cut

sub fileno { $_[0][0] }

1;
