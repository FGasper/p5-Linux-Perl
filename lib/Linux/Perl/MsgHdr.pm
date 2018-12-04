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

    _cmsghdr_unpack => q< x[L!] i! i! a* >,

    # buffer, length
    _iov => q< P L! >,

    _iov_lengths => q< x[P] L! >,

    _sizelen => length( pack 'L!' ),
    _intlen  => length( pack 'i!' ),
};

my ($cmsg_len_w_padding, $ctrl_ar, $cmsg_datalen_plus_padding);

sub pack_control {
    my ($ctrl_ar) = @_;

    return join(
        q<>,
        map {
            $cmsg_len_w_padding = CMSG_ALIGN( length $ctrl_ar->[ 2 + 3 * $_ ] );
            pack(
                "L! i! i! a$cmsg_len_w_padding",
                _sizeof_cmsghdr() + length $ctrl_ar->[ 2 + 3 * $_ ],
                @{$ctrl_ar}[ 3 * $_, 1 + 3 * $_ ],
                $ctrl_ar->[ 2 + 3 * $_ ],
            );
        } 0 .. (@$ctrl_ar / 3 - 1),
    );
}

sub pack_msghdr {
    my ($opts_hr) = @_;

    my $control = $opts_hr->{'control'} && pack_control($opts_hr->{'control'});

    # We have to join() individual pack()s rather than doing one giant
    # pack() to avoid pack()ing pointers to temporary values.
    my $iov_buf = $opts_hr->{'iov'} && join(
        q<>,
        map { pack( _iov(), $$_, length $$_) } @{ $opts_hr->{'iov'} },
    );

    return [
        \pack(
            _msghdr(),

            $opts_hr->{'name'} && ${ $opts_hr->{'name'} },
            defined($opts_hr->{'name'}) ? length( ${ $opts_hr->{'name'} } ) : 0,

            $iov_buf,
            $opts_hr->{'iov'} ? 0 + @{ $opts_hr->{'iov'} } : 0,

            $control,
            $control ? length( $control ) : 0,
        ),
        \$iov_buf,
        \$control,
    ];
}

use constant {
    _sizeof_long => length pack( 'L!' ),
    _sizeof_cmsghdr => length pack( _cmsghdr() ),
};

sub CMSG_ALIGN {
    return ( ( $_[0] + _sizeof_long - 1 ) & ~( _sizeof_long - 1 ) );
}

sub CMSG_SPACE {
    return( _sizeof_cmsghdr() + CMSG_ALIGN($_[0]) );
}

1;
