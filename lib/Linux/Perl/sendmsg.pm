package Linux::Perl::sendmsg;

=encoding utf-8

=head1 NAME

Linux::Perl:sendmsg:

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use parent 'Linux::Perl::Base';

use Linux::Perl;
use Linux::Perl::ParseFlags;

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

    _flag_CONFIRM   => 0x800,
    _flag_DONTROUTE => 4,
    _flag_DONTWAIT => 0x40,
    _flag_EOR => 0x80,
    _flag_MORE => 0x8000,
    _flag_NOSIGNAL => 0x4000,
    _flag_OOB => 1,
};

# fd, flags, name, iov, control(level, type, data)
sub sendmsg {
    my ($class, %opts) = @_;

    $class = $class->_get_arch_module();

    my $flags = Linux::Perl::ParseFlags::parse(
        $class,
        $opts{'flags'},
    );

    # Without this we get warnings:
    #
    #   Attempt to pack pointer to temporary value
    #
    # These warnings seem irrelevant since the data
    # is sent immediately.
    no warnings 'pack';

    my $control = $opts{'control'} && pack(
        _cmsghdr(),
        16 + length $opts{'control'}[2],
        @{ $opts{'control'} },
    );

    my $msg = pack(
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

    return Linux::Perl::call(
        $class->NR_sendmsg(),
        0 + $opts{'fd'},
        $msg,
        0 + $flags,
    );
}

1;
