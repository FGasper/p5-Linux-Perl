package Linux::Perl::MsgHdr;

use strict;
use warnings;

use constant {
    _msghdr => q<
        P   # name
        L!  # namelen
        P   # iov
        L!  # iovlen
        P   # control
        L!  # controllen
        x[I!]
    >,

    _cmsghdr => q<
        L!  # len
        i!  # level
        i!  # type
        a*  # data
    >,

    # buffer, length
    _iovec => q< P L! >,

    _sizelen => length( pack 'L!' ),
    _intlen  => length( pack 'I!' ),
};

sub pack_msghdr {
    my (%opts) = @_;

    # Without this we get warnings:
    #
    #   Attempt to pack pointer to temporary value
    #
    # These warnings seem irrelevant since the data
    # is sent immediately.
    no warnings 'pack';

    my $control = $opts{'control'} && pack(
        _cmsghdr(),
        _sizelen() + 2 * _intlen() + length $opts{'control'}[2],
        @{ $opts{'control'} },
    );

    return pack(
        _msghdr(),

        $opts{'name'},
        defined($opts{'name'}) ? length($opts{'name'}) : 0,

        $opts{'iov'} && join(
            q<>,
            map { pack( _iovec(), $$_, length $$_) } @{ $opts{'iov'} },
        ),
        $opts{'iov'} ? 0 + @{ $opts{'iov'} } : 0,

        $control,
        length( $control || q<> ),
    );
}

1;
