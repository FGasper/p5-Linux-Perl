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

    _msghdr_lengths => q<
        x[P]    # name
        L!      # namelen
        x[P]    # iov
        L!      # iovlen
        x[P]    # control
        L!      # controllen
    >,

    _cmsghdr => q<
        L!  # len
        i!  # level
        i!  # type
        a*  # data
    >,

    # buffer, length
    _iovec => q< P L! >,

    _iovec_lengths => q< x[P] L! >,

    _sizelen => length( pack 'L!' ),
    _intlen  => length( pack 'i!' ),
};

# Tightly coupled to recvmsg.
sub shrink_opt_strings {
    my ($msghdr_sr, $iov_buf_sr, %opts) = @_;

    my ($namelen, $iovlen, $controllen) = unpack _msghdr_lengths(), $$msghdr_sr;

    if ($opts{'control'}) {
        if ($controllen) {
            $controllen -= (_sizelen() + 2 * _intlen());
            substr( ${ $opts{'control'}[2] }, $controllen ) = q<>;
        }
        else {
            splice( @{ $opts{'control'} }, 0, 2 );
        }
    }

    if ($opts{'name'}) {
        substr( ${ $opts{'name'} }, $namelen ) = q<>;
    }

    my @iov_lengths = unpack(
        _iovec_lengths() x $iovlen,
        $$iov_buf_sr,
    );

    for my $n ( 0 .. $#iov_lengths ) {
        substr( ${ $opts{'iov'}[$n] }, $iov_lengths[$n] ) = q<>;
    }

    return;
}

sub pack_msghdr {
    my (%opts) = @_;

    my $control = $opts{'control'} && pack(
        _cmsghdr(),
        _sizelen() + 2 * _intlen() + length ${ $opts{'control'}[2] },
        @{ $opts{'control'} }[0, 1],
        ${ $opts{'control'}[2] },
    );

    # We have to join() individual pack()s rather than doing one giant
    # pack() to avoid pack()ing pointers to temporary values.
    my $iov_buf = $opts{'iov'} && join(
        q<>,
        map { pack( _iovec(), $$_, length $$_) } @{ $opts{'iov'} },
    );

    return [
        \pack(
            _msghdr(),

            ${ $opts{'name'} },
            defined($opts{'name'}) ? length(${ $opts{'name'} }) : 0,

            $iov_buf,
            $opts{'iov'} ? 0 + @{ $opts{'iov'} } : 0,

            $control,
            $control ? length( $control ) : 0,
        ),
        \$iov_buf,
        \$control,
    ];
}

1;
