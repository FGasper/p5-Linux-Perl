package Linux::Perl::sendmsg;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Linux::Perl::sendmsg

=head1 SYNOPSIS

    my $bytes = Linux::Perl::sendmsg->sendmsg(
        fd => $fd,
        name => $name,
        iovec => [ \$str1, \$str2, .. ],
        control => [ $level, $type, $data ],
        flags => \@flags,
    );

You can alternatively use your platform-specific module, e.g.,
L<Linux::Perl::sendmsg::x86_64>.

=head1 DESCRIPTION

This module provides a Linux-specific C<sendmsg()> implementation.
See C<man 2 sendmsg> for what this can do differently from C<send()>
and C<sendto>.

=cut

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
    _intlen  => length( pack 'I!' ),

    _flag_CONFIRM   => 0x800,
    _flag_DONTROUTE => 4,
    _flag_DONTWAIT => 0x40,
    _flag_EOR => 0x80,
    _flag_MORE => 0x8000,
    _flag_NOSIGNAL => 0x4000,
    _flag_OOB => 1,
};

=head1 METHODS

=head2 I<CLASS>->sendmsg( %OPTS )

%OPTS correspond to the system call:

=over

=item * C<fd>

=item * C<name> - irrelevant for connected sockets

=item * C<iovec> - Optional, a reference to an array of string references

=item * C<control> - Optional, a reference to an array of: $LEVEL, $TYPE, $DATA.
See below for examples. If you don’t use this, you might as well use Perl’s
C<send()> built-in.

=item * C<flags> - Optional, a reference to an array of any/all of: C<CONFIRM>,
C<DONTROUTE>, C<DONTWAIT>, C<EOR>, C<MORE>, C<NOSIGNAL>, C<OOB>.

=back

=cut

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
        _sizelen() + 2 * _intlen() + length $opts{'control'}[2],
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

#----------------------------------------------------------------------

=head1 CONTROL EXAMPLES

=head2 Sending credentials via local socket

    use Socket;

    control => [
        Socket::SOL_SOCKET(), Socket::SCM_CREDENTIALS(),
        pack( 'I!*', $$, $>, split( m< >, $) ) ),
    ]

=head2 Passing open file descriptors via local socket

    control => [
        Socket::SOL_SOCKET(), Socket::SCM_RIGHTS(),
        pack( 'I!*', @file_descriptors ),
    ]

Also see L<Socket::MsgHdr>’s documentation for another example.

=head1 TODO

I’m not sure if C<recvmsg()> is feasible to implement in pure Perl,
but that would be a natural complement to this module.

=cut

1;
