package Linux::Perl::recvmsg;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Linux::Perl::recvmsg

=head1 SYNOPSIS

    my $msg = Linux::Perl::recvmsg->new(
        namelen => 48,
        ioveclen => [ 128, 256 ],
        controllen => [ 12, 48 ],
        flags => \@flags,   # or numeric
    );

    my $bytes = $msg->recvmsg($fh);

Accessors, probably useful for after you’ve received a message:

    my $name = $msg->get_name();

    my @iovec = $msg->get_iovec();

    my @control = $msg->get_control();

    my @flags = $msg->get_flag_names();
    my $flags = $msg->get_flags();

You can reuse the same message object to receive further messages:

    $msg->set_namelen(56);
    $msg->set_ioveclen(200, 300);
    $msg->set_controllen(20, 40);

    $msg->set_flag_names('CMSG_CLOEXEC', 'DONTWAIT');

    my $cmsg_cloexec = $msg->FLAGS()->{'CMSG_CLOEXEC'};
    my $dontwait = $msg->FLAGS()->{'DONTWAIT'};
    $msg->set_flags( $cmsg_cloexec | $dontwait );

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

use constant FLAG => {
    CMSG_CLOEXEC   => 0x40000000,
    DONTWAIT => 0x40,
    ERRQUEUE => 0x2000,
    OOB => 1,
    PEEK => 2,
    TRUNC => 32,
    WAITALL => 256,

    EOR => 0x80,
    CTRUNC => 8,
};

use constant {
    _EAGAIN => 11,

    _flag_CMSG_CLOEXEC   => 0x40000000,
    _flag_DONTWAIT => 0x40,
    _flag_ERRQUEUE => 0x2000,
    _flag_OOB => 1,
    _flag_PEEK => 2,
    _flag_TRUNC => 32,
    _flag_WAITALL => 256,
    _flag_CTRUNC => 8,
};

=head1 METHODS

=head2 I<OBJ>->new( %OPTS )

Returns an instance of this class.

%OPTS correspond to the system call arguments:

=over

=item * C<namelen> - Irrelevant for connected sockets; required otherwise.

=item * C<ioveclen> - Optional, a reference to an array of
string lengths.

=item * C<control> - Optional, a reference to an array of control/ancillary
message payload lengths.

=item * C<flags> - Optional, a reference to an array of any/all of:
C<CMSG_CLOEXEC>, C<DONTWAIT>, C<ERRQUEUE>, C<PEEK>, C<WAITALL>.

=back

=cut

sub new {
    my ($class, %opts) = @_;

    $class = $class->_get_arch_module();

    my $flags = Linux::Perl::ParseFlags::parse(
        $class,
        $opts{'flags'},
    );

    my $name = "\0" x (delete $opts{'namelen'} || 0);

    my @iovec;
    if ($opts{'ioveclen'}) {
        @iovec = map { "\0" x $_ } @{ delete $opts{'ioveclen'} };
    }

    my @control;
    if ($opts{'controllen'}) {
        @control = map { "\0" x Linux::Perl::MsgHdr::CMSG_SPACE($_) } @{ delete $opts{'ioveclen'} };
    }

    my %self = (
        name => $name,
        iovec => \@iovec,
        control => \@control,
        flags => $flags,
    );

    return bless \%self, $class;
}

#----------------------------------------------------------------------

=head2 $bytes = I<CLASS>->recvmsg( $FD_OR_FH )

Attempts to receive a message.

If EAGAIN/EWOULDBLOCK is encountered, undef is returned.

=cut

# fd, flags, name, iov, control(level, type, data)
sub recvmsg {
    my ($self, $fd) = @_;

    $fd = fileno $fd if ref $fd;

    my $packed_ar = Linux::Perl::MsgHdr::pack_msghdr($self);

    local @Linux::Perl::_TOLERATE_ERRNO = ( _EAGAIN() );

    my $ret = Linux::Perl::call(
        $self->NR_recvmsg(),
        0 + $fd,
        ${ $packed_ar->[0] },
        0 + $self->{'flags'},
    );

    return undef if -1 == $ret;

    my ($namelen, $iov_ct, $controllen) = unpack Linux::Perl::MsgHdr::_msghdr_lengths(), ${ $packed_ar->[0] };

    my @iov_lengths = unpack(
        Linux::Perl::MsgHdr::_iovec_lengths() x $iov_ct,
        ${ $packed_ar->[1] },
    );

    @{$self}{'_namelen', '_iov_lengths', '_controllen', '_packed'} = ($namelen, \@iov_lengths, $controllen, $packed_ar);

#    Linux::Perl::MsgHdr::shrink_opt_strings(
#        @$packed_ar,
#        %opts,
#    );

    return $ret;
}

#----------------------------------------------------------------------

sub get_name {
    return substr( $_[0]->{'name'}, 0, $_[0]->{'_namelen'} );
}

#sub get_iovec {
#    my ($self) = @_;
#
#    my @iovec;
#
#    my $iov_lens = $self->{'_iov_lengths'};
#
#    for my $i ( 0 .. $#$iov_lens ) {
#        if ($iov_lens->[$i] != length $self->{'iovec'}[$i]) {
#            substr( $self->{'iovec'}[$i], $iov_lens->[$i] ) = q<>;
#        }
#
#        push @iovec, \$self->{'iovec'}[$i];
#    }
#
#    return \@iovec;
#}

sub get_iovec {
    my ($self) = @_;

    my @iovec;

    for my $i ( 0 .. $#{ $self->{'_iov_lengths'} } ) {
        push @iovec, \substr( $self->{'iovec'}[$i], 0, $self->{'_iov_lengths'}[$i] );
    }

    return \@iovec;
}

sub get_control {
    my ($self) = @_;

    my @control;

    my $i = 0;
    while ($i < $self->{'_controllen'}) {
        my $str = unpack "\@$i L!/A*", $self->{'_packed'};

        push @control, unpack 'i! i! a*', $str;

        $i += Linux::Perl::MsgHdr::CMSG_ALIGN( length $str );
    }

    return \@control;
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
