package Linux::Perl::recvmsg;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Linux::Perl::recvmsg

=head1 SYNOPSIS

    my $bytes = Linux::Perl::recvmsg->recvmsg(
        fd => $fd,
        name => $name,
        iovec => [ \$str1, \$str2, .. ],
        control => \$data,???
        flags => \@flags,
    );

You can alternatively use your platform-specific module, e.g.,
L<Linux::Perl::recvmsg::x86_64>.

=head1 DESCRIPTION

This module provides a Linux-specific C<recvmsg()> implementation.
See C<man 2 recvmsg> for what this can do differently from C<recv()>
and C<recvfrom>.

=cut

use parent 'Linux::Perl::Base';

use Linux::Perl;
use Linux::Perl::MsgHdr;
use Linux::Perl::ParseFlags;

use constant {
    _EAGAIN => 11,

    _flag_CMSG_CLOEXEC   => 0x40000000,
    _flag_DONTWAIT => 0x40,
    _flag_ERRQUEUE => 9999, # XXX TODO
    _flag_OOB => 1,
    _flag_PEEK => 2,
    _flag_TRUNC => 32,
    _flag_WAITALL => 256,
};

=head1 METHODS

=head2 $bytes = I<CLASS>->recvmsg( %OPTS )

If EAGAIN/EWOULDBLOCK is encountered, undef is returned.

%OPTS correspond to the system call arguments:

=over

=item * C<fd>

=item * C<name> - Irrelevant for connected sockets; required otherwise. Give as an empty string

=item * C<iovec> - Optional, a reference to an array of
string references. These will be B<mutated> to contain
the received bytes.

=item * C<control> - Optional, a reference to an array
that contains a reference to a single string ($DATA).
If any control
information arrives in the message, the level and type
will be unshifted (in that order) onto the array, and
$DATA will be populated with the received data. See
below for examples. If you don’t use this, you might
as well use Perl’s C<recv()> built-in.

=item * C<flags> - Optional, a reference to an array of any/all of: C<CONFIRM>,
C<DONTROUTE>, C<DONTWAIT>, C<EOR>, C<MORE>, C<NOSIGNAL>, C<OOB>.

=back

=cut

# fd, flags, name, iov, control(level, type, data)
sub recvmsg {
    my ($class, %opts) = @_;

    $class = $class->_get_arch_module();

    my $flags = Linux::Perl::ParseFlags::parse(
        $class,
        $opts{'flags'},
    );

    if ($opts{'control'}) {
        unshift @{ $opts{'control'} }, 0, 0;
    }

    my $packed_ar = Linux::Perl::MsgHdr::pack_msghdr(%opts);

    local @Linux::Perl::_TOLERATE_ERRNO = ( _EAGAIN() );

    my $ret = Linux::Perl::call(
        $class->NR_recvmsg(),
        0 + $opts{'fd'},
        ${ $packed_ar->[0] },
        0 + $flags,
    );

    Linux::Perl::MsgHdr::shrink_opt_strings(
        @$packed_ar,
        %opts,
    );

    return( (-1 == $ret) ? undef : $ret );
}

#----------------------------------------------------------------------

=head1 CONTROL EXAMPLE

    use Socket;

    my $name = "\0" x 256;
    my $main_data = "\0" x 256;
    my $control_data = "\0" x 48;

    # Can receive up to 256 bytes of payload
    # and 48 bytes of control data. We receive
    # a name that can be up to 256 bytes long.
    Linux::Perl::recvmsg->recvmsg(
        fd => fileno $fh,
        name => \$name,
        iovec => [ \$main_data ],
        control => [ \$control_data ],
        flags => [ 'DONTWAIT' ],
    );

=head1 SEE ALSO

L<Socket::MsgHdr> provides an XS-based implementation of
C<sendmsg()> and C<recvmsg()>.

=cut

1;
