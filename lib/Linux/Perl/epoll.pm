package Linux::Perl::epoll;

use strict;
use warnings;

use Linux::Perl;
use Linux::Perl::Constants::Fcntl;
use Linux::Perl::EasyPack;
use Linux::Perl::ParseFlags;
use Linux::Perl::SigSet;

*_flag_CLOEXEC = \*Linux::Perl::Constants::Fcntl::flag_CLOEXEC;

sub new {
    my ($class, %opts) = @_;

    local ($!, $^E);

    my $arch_module = $class->can('NR_epoll_create') && $class;
    $arch_module ||= do {
        require Linux::Perl::ArchLoader;
        Linux::Perl::ArchLoader::get_arch_module($class);
    };

    my $flags = Linux::Perl::ParseFlags::parse( $class, $opts{'flags'} );

    my $call_name = 'NR_epoll_create';

    my $fd;

    if ($flags) {
        $call_name .= '1';

        $fd = Linux::Perl::call( $arch_module->$call_name(), 0 + $flags );
    }
    else {
        $opts{'size'} ||= 1;

        $fd = Linux::Perl::call( $arch_module->$call_name(), 0 + $opts{'size'} );
    }

    # Force the CLOEXEC behavior that Perl imposes on its file handles
    # unless the CLOEXEC flag was given explicitly.
    my $fh;

    if ( !($flags & _flag_CLOEXEC()) ) {
        open $fh, '+<&=' . $fd;
    }

    # NB: tests access the filehandle directly.
    return bless [$fd, $fh], $arch_module;
}

my ($epoll_event_keys_ar, $epoll_event_pack);

BEGIN {
    my @_epoll_event_src = (
        events => 'L',
        data   => 'I!',
    );

    ($epoll_event_keys_ar, $epoll_event_pack) = Linux::Perl::EasyPack::split_pack_list(@_epoll_event_src);
}

use constant {
    _EPOLL_CTL_ADD => 1,
    _EPOLL_CTL_DEL => 2,
    _EPOLL_CTL_MOD => 3,

    _event_num => {
        IN => 1,
        OUT => 4,
        RDHUP => 0x2000,
        PRI => 2,
        ERR => 8,
        HUP => 16,
        ET => (1 << 31),
        ONESHOT => (1 << 30),
        WAKEUP => (1 << 29),
        EXCLUSIVE => (1 << 28),
    },
};

use constant _event_name => { reverse %{ _event_num() } };

=head2 I<OBJ>->add( $FD_OR_FH, %OPTS )

Adds a listener to the epoll instance. $FD_OR_FH is either a
Perl filehandle or a file descriptor number. %OPTS are:

=over

=item * C<events> - An array reference of events/switches. The
recognized event names are: C<IN>, C<OUT>, C<RDHUP>, C<PRI>, C<ERR>,
C<HUP>, C<ET>, C<ONESHOT>, C<WAKEUP>, and C<EXCLUSIVE>. Your kernel
may not support all of those; check C<man 2 epoll_ctl> for details.

=item * C<data> - Optional, an arbitrary number to store with the file
descriptor. This defaults to the file descriptor.

=back

=cut

sub add {
    my ($self, $fd_or_fh, @opts_kv) = @_;

    return $self->_add_or_modify( _EPOLL_CTL_ADD(), $fd_or_fh, @opts_kv );
}

=head2 I<OBJ>->modify( $FD_OR_FH, %OPTS )

Same arguments as C<add()>.

=cut

sub modify {
    my ($self, $fd_or_fh, @opts_kv) = @_;

    return $self->_add_or_modify( _EPOLL_CTL_MOD(), $fd_or_fh, @opts_kv );
}

sub _opts_to_event {
    my ($opts_hr) = @_;

    if (!$opts_hr->{'events'} || !@{ $opts_hr->{'events'} }) {
        die 'Need events!';
    }

    my $events = 0;
    for my $evtname ( @{ $opts_hr->{'events'} } ) {
        $events |= _event_num()->{$evtname} || do {
            die "Unknown event '$evtname'";
        };
    }

    return pack $epoll_event_pack, $events, $opts_hr->{'data'};
}

sub _add_or_modify {
    my ($self, $op, $fd_or_fh, %opts) = @_;

    my $fd = ref($fd_or_fh) ? fileno($fd_or_fh) : $fd_or_fh;

    if (!defined $opts{'data'}) {
        $opts{'data'} = $fd;
    }

    my $event_packed = _opts_to_event(\%opts);

    Linux::Perl::call(
        $self->NR_epoll_ctl(),
        0 + $self->[0],
        0 + $op,
        0 + $fd,
        $event_packed,
    );

    return $self;
}

#----------------------------------------------------------------------

=head2 I<OBJ>->delete( $FD_OR_FH )

Same arguments as C<add()>.

=cut

sub delete {
    my ($self, $fd_or_fh) = @_;

    my $fd = ref($fd_or_fh) ? fileno($fd_or_fh) : $fd_or_fh;

    Linux::Perl::call(
        $self->NR_epoll_ctl(),
        0 + $self->[0],
        0 + _EPOLL_CTL_DEL(),
        0 + $fd,
        (pack $epoll_event_pack),   #accommodate pre-2.6.9 kernels
    );

    return $self;
}

#----------------------------------------------------------------------

=head2 @events = I<OBJ>->wait( %OPTS )

Waits for one or more events on the epoll. %OPTS are:

=over

=item * C<maxevents> - The number of events to listen for.

=item * C<timeout> - in seconds

=item * C<sigmask> - Optional, an array of signals to mask. The signals
can be specified either as names (e.g., C<INT>) or as numbers.
See C<man 2 epoll_pwait> for why you might want to do this.

=back

The return is a list of hash references, one for each received event.
Each hash reference has C<events> and C<data>, analogous to the same
inputs as given to C<add()> above.

=cut

sub wait {
    my ($self, %opts) = @_;

    my $sigmask;

    my $call_name = 'NR_epoll_';
    if ($opts{'sigmask'} && @{$opts{'sigmask'}}) {
        $call_name .= 'pwait';
        $sigmask = Linux::Perl::SigSet::from_list( @{$opts{'sigmask'}} );
    }
    else {
        $call_name .= 'wait';
    }

    my $blank_event = pack $epoll_event_pack;
    my $buf = $blank_event x $opts{'maxevents'};

    my $timeout = int(1000 * $opts{'timeout'});

    my $count = Linux::Perl::call(
        $self->$call_name(),
        0 + $self->[0],
        $buf,
        0 + $opts{'maxevents'},
        0 + $timeout,
        ( length($sigmask)
            ? ( $sigmask, length $sigmask )
            : (),
        ),
    );

    my @events;
    for (1 .. $count) {
        my ($events_num, $data) = unpack( $epoll_event_pack, substr( $buf, 0, length($blank_event), q<> ) );

        push @events, {
            events => _events_to_ar($events_num),
            data => $data,
        };
    }

    return @events;
}

sub _events_to_ar {
    my ($events_num) = @_;

    my $name_hr = _event_name();

    my @events;
    for my $evt_num ( keys %$name_hr ) {
        if ($events_num & $evt_num) {
            push @events, $name_hr->{$evt_num};
        }
    }

    return \@events;
}

1;
