package Linux::Perl::sendmsg;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Linux::Perl::sendmsg

=head1 SYNOPSIS

    my $msg = Linux::Perl::sendmsg->new(
        name => $name,
        iovec => [ \$str1, \$str2, .. ],
        control => [ $level, $type, $data ],
        flags => \@flags,
    );

    my $bytes = $msg->sendmsg($fh);

You can alternatively use your platform-specific module, e.g.,
L<Linux::Perl::sendmsg::x86_64>.

=head1 DESCRIPTION

This module provides a Linux-specific L<sendmsg(2)> implementation.
Read the man pages for what this can do differently from L<send(2)>
and L<sendto(2)>.

=cut

use parent 'Linux::Perl::Base';

use Linux::Perl;
use Linux::Perl::MsgHdr;
use Linux::Perl::ParseFlags;

use constant {
    _EAGAIN => 11,

    _flag_CONFIRM   => 0x800,
    _flag_DONTROUTE => 4,
    _flag_DONTWAIT => 0x40,
    _flag_EOR => 0x80,
    _flag_MORE => 0x8000,
    _flag_NOSIGNAL => 0x4000,
    _flag_OOB => 1,
};

=head1 METHODS

=head2 $obj = I<CLASS>->new( %OPTS )

Returns an object instance.

%OPTS correspond to the system call arguments:

=over

=item * C<name> - Plain string. Irrelevant for connected sockets;
required otherwise.

=item * C<iovec> - Optional, a reference to an array of string references.

=item * C<control> - Optional, a reference to an array of 1 or more of:
( $LEVEL, $TYPE, \$DATA ).  See below for examples. If you don’t use this
or multiple string references in C<iovec>, you might as well use Perl’s
C<send()> built-in.

=item * C<flags> - Optional, either of:

=over

=item * a reference to an array of any/all of: C<CONFIRM>,
C<DONTROUTE>, C<DONTWAIT>, C<EOR>, C<MORE>, C<NOSIGNAL>, C<OOB>.

=item * a number that ORs the corresponding members of C<FLAGS()> together.

=back

=back

=cut

sub new {
    my ($class, %opts) = @_;

    $class = $class->_get_arch_module();

    # _validate_control($opts{'control'}) if $opts{'control'};

    if ('ARRAY' eq ref $opts{'flags'}) {
        $opts{'flags'} = Linux::Perl::ParseFlags::parse(
            $class,
            $opts{'flags'},
        );
    }

    return bless \%opts, $class;
}

=head2 $bytes = I<OBJ>->sendmsg( $FH_OR_FD )

Sends the message and returns the number of bytes sent.

If EAGAIN/EWOULDBLOCK is encountered, undef is returned.

=cut

sub sendmsg {
    my ($self, $fd) = @_;

    $fd = fileno $fd if ref $fd;

    local @Linux::Perl::_TOLERATE_ERRNO = ( _EAGAIN() );

    my $packed_ar = Linux::Perl::MsgHdr::pack_msghdr(%$self);

    my $ret = Linux::Perl::call(
        $self->NR_sendmsg(),
        0 + $fd,
        ${ $packed_ar->[0] },
        0 + ($opts{'flags'} || 0),
    );

    return( (-1 == $ret) ? undef : $ret );
}

#sub _validate_control {
#    if (@{ $_[0] } % 3) {
#        die "“control” must consist of multiples of 3!";
#    }
#
#    return;
#}

=head2 $obj = I<OBJ>->set_name( $NAME )

Sets the message’s name.

=cut

sub set_name {
    $_[0]->{'name'} = $_[1];

    return $_[0];
}

=head2 $obj = I<OBJ>->set_iovec( \$STR1, \$STR2, .. )

Sets the message’s payload.

=cut

sub set_iovec {
    if ($_[0]->{'iovec'}) {
        @{ $_[0]->{'iovec'} } = @_[1 .. $#_ ];
    }
    else {
        $_[0]->{'iovec'} = [ @_[1 .. $#_ ] ];
    }

    return $_[0];
}

=head2 $obj = I<OBJ>->set_control( $LVL1, $TYPE1, $DATA1, .. )

Sets the message’s control/ancillary data.

=cut

sub set_control {
    if ($_[0]->{'control'}) {
        @{ $_[0]->{'control'} } = @_[1 .. $#_ ];
    }
    else {
        $_[0]->{'control'} = [ @_[1 .. $#_ ] ];
    }

    return $_[0];
}

=head2 $obj = I<OBJ>->set_flag_names( @FLAGS )

Sets the message’s flags as a list of strings.
See the corresponding constructor argument for details.

=cut

sub set_flag_names {
    $_[0]->{'flags'} = Linux::Perl::ParseFlags::parse(
        (ref $_[0]),
        [ @_[ 1 .. $#_ ] ],
    );

    return $_[0];
}

=head2 $obj = I<OBJ>->set_flags( $NUMBER )

Like C<set_flag_names()>, but accepts the numeric form.

=cut

sub set_flags {
    $_[0]->{'flags'} = $_[1];

    return $_[0];
}

#----------------------------------------------------------------------

=head1 CONTROL EXAMPLES

=head2 Sending credentials via local socket

    use Socket;

    control => [
        Socket::SOL_SOCKET(), Socket::SCM_CREDENTIALS(),
        \pack( 'I!*', $$, $>, (split m< >, $))[0] ),
    ]

=head2 Passing open file descriptors via local socket

    control => [
        Socket::SOL_SOCKET(), Socket::SCM_RIGHTS(),
        \pack( 'I!*', @file_descriptors ),
    ]

Also see L<Socket::MsgHdr>’s documentation for another example.

=head1 TODO

I’m not sure if C<recvmsg()> is feasible to implement in pure Perl,
but that would be a natural complement to this module.

=head1 SEE ALSO

L<Socket::MsgHdr> provides both C<sendmsg()> and C<recvmsg()>.

=cut

1;
