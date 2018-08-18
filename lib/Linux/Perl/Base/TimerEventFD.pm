package Linux::Perl::Base::TimerEventFD;

use strict;
use warnings;

use Linux::Perl::Endian;

use constant _PERL_CAN_64BIT => !!do { local $@; eval { pack 'Q', 1 } };

#----------------------------------------------------------------------

=head2 I<OBJ>->fileno()

Returns the file descriptor number.

=cut

sub fileno { fileno $_[0][0] }

#----------------------------------------------------------------------

sub _read {
    return undef if !sysread $_[0][0], my $buf, 8;

    return _parse64($buf);
}

my ($big, $low);

sub _parse64 {
    my ($buf) = @_;

    if (_PERL_CAN_64BIT) {
        $low = unpack('Q', $buf);
    }
    else {
        if (Linux::Perl::Endian::SYSTEM_IS_BIG_ENDIAN()) {
            ($big, $low) = unpack 'NN', $buf;
        }
        else {
            ($low, $big) = unpack 'VV', $buf;
        }

        #TODO: Need to test what happens on a 32-bit Perl.
        die "No 64-bit support! (high=$big, low=$low)" if $big;
    }

    return $low;
}

1;
