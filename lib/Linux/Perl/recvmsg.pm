package Linux::Perl::recvmsg;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Linux::Perl::recvmsg

=head1 SYNOPSIS

    my $msg = Linux::Perl::recvmsg->new(
        namelen => 48,
        iovlen => [ 128, 256 ],
        controllen => [ 12, 48 ],
        flags => \@flags,   # or numeric
    );

    my $bytes = $msg->recvmsg($fh);

Accessors, probably useful for after you’ve received a message:

    my $name = $msg->get_name();

    my @iov = $msg->get_iov();

    my @control = $msg->get_control();

    my @flags = $msg->get_flag_names();
    my $flags = $msg->get_flags();

You can reuse the same message object to receive further messages:

    $msg->set_namelen(56);
    $msg->set_iovlen(200, 300);
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

=item * C<iovlen> - Optional, a reference to an array of
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

   my @iov;
   if ($opts{'iovlen'}) {
       @iov = map { \("\0" x $_) } @{ delete $opts{'iovlen'} };
   }

   my @control;
   if ($opts{'controllen'}) {
       @control = map { ( 0, 0, "\0" x Linux::Perl::MsgHdr::CMSG_SPACE($_) ) } @{ delete $opts{'controllen'} };
    }

    my %self = (
        name => $name,
        iov => \@iov,
        control => \@control,
        flags => $flags,
    );

    return bless \%self, $class;
}

#----------------------------------------------------------------------

=head2 $bytes = I<OBJ>->recvmsg( $FD_OR_FH )

Attempts to receive a message.

If EAGAIN/EWOULDBLOCK is encountered, undef is returned; any other
error prompts an exception.

=cut

# fd, flags, name, iov, control(level, type, data)
sub recvmsg {
    my ($self, $fd) = @_;

    $fd = fileno $fd if ref $fd;

    my $packed_ar = Linux::Perl::MsgHdr::pack_msghdr($self);

    local @Linux::Perl::_TOLERATE_ERRNO = ( _EAGAIN() );

    my $bytes = Linux::Perl::call(
        $self->NR_recvmsg(),
        0 + $fd,
        ${ $packed_ar->[0] },
        0 + $self->{'flags'},
    );

    return undef if -1 == $bytes;

    my ($namelen, $iov_ct, $controllen) = unpack Linux::Perl::MsgHdr::_msghdr_lengths(), ${ $packed_ar->[0] };

    my @iov_lengths = unpack(
        Linux::Perl::MsgHdr::_iov_lengths() x $iov_ct,
        ${ $packed_ar->[1] },
    );

    @{$self}{'_namelen', '_iov_lengths', '_controllen', '_packed', '_got_bytes'} = ($namelen, \@iov_lengths, $controllen, $packed_ar, $bytes);

    return $bytes;
}

#----------------------------------------------------------------------

=head2 $name = I<OBJ>->get_name()

Returns the name component of the received message.

=cut

sub get_name {
    return substr( $_[0]->{'name'}, 0, $_[0]->{'_namelen'} );
}

#----------------------------------------------------------------------

=head2 $iov_ar = I<OBJ>->get_iov()

Returns a reference to an array of string references that represent the
last-received payload. The references may
or may not be the actual object internals; callers are expected to copy
the strings before changing them!

=cut

sub get_iov {
    my ($self) = @_;

    my @iov;

    my $bytes = $self->{'_got_bytes'};

    for my $i ( 0 .. $#{ $self->{'_iov_lengths'} } ) {
        if ( length ${ $self->{'iov'}[$i] } > $bytes ) {
            push @iov, \do { substr( ${ $self->{'iov'}[$i] }, 0, $bytes ) };
            last;
        }
        else {
            push @iov, $self->{'iov'}[$i];
        }

        $bytes -= length ${ $self->{'iov'}[$i] };

        # Prevent a final empty string.
        last if $bytes == 0;
    }

    return \@iov;
}

#----------------------------------------------------------------------

=head2 $ctrl_ar = I<OBJ>->get_control()

Returns the control/ancillary elements of the message as a reference
to an array of 3-element groups: ( $level, $type, $data ).

=cut

sub get_control {
    my ($self) = @_;

    my @control;

    my $i = 0;
    while ($i < $self->{'_controllen'}) {

        # $len is inclusive of its own encoding.
        # $str overshoots by the length of $len's encoding.
        my ($len, $str) = unpack "\@$i L! \@$i L!/a*", ${ $self->{'_packed'}[2] };
        die "Failed to unpack control at index $i!" if !defined $str;

        $i += Linux::Perl::MsgHdr::CMSG_ALIGN($len);

        # shorten as needed so that we don't overshoot
        substr( $str, $len - length( pack 'L!' ) ) = q<>;

        push @control, unpack 'i! i! a*', $str;
    }

    return \@control;
}

#----------------------------------------------------------------------

sub set_namelen {
    die 'TODO';
}

sub set_iovlen {
    $_[0]{'iov'} = [ map { \("\0" x $_) } @_[ 1 .. $#_ ] ];

    return $_[0];
}

sub set_controllen {
    $_[0]{'control'} = [
        map { ( 0, 0, "\0" x $_ ) } @_[ 1 .. $#_ ]
    ];

    return $_[0];
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
    my $msg = Linux::Perl::recvmsg->new(
        namelen => 256,
        iovlen => [ 256 ],
        controllen => 48,
        flags => [ 'DONTWAIT' ],
    );

    my $bytes = $msg->recvmsg( $fh );

=head1 SEE ALSO

L<Socket::MsgHdr> provides an XS-based implementation of
C<sendmsg()> and C<recvmsg()>.

=cut

1;
