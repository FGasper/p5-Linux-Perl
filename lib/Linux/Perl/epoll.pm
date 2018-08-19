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

sub add {
    my ($self, $fd_or_fh, @opts_kv) = @_;

    return $self->_add_or_modify( _EPOLL_CTL_ADD(), $fd_or_fh, @opts_kv );
}

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
        $events |= _evt_num()->{$evtname} || do {
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

sub delete {
    my ($self, $fd_or_fh) = @_;

    my $fd = ref($fd_or_fh) ? fileno($fd_or_fh) : $fd_or_fh;

    Linux::Perl::call(
        $self->NR_epoll_ctl(),
        0 + $self->[0],
        0 + _EPOLL_CTL_DEL(),
        0 + $fd,
        undef,
    );

    return $self;
}

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

    my $count = Linux::Perl::call(
        $self->call_name(),
        0 + $self->[0],
        $buf,
        0 + $opts{'maxevents'},
        0 + $opts{'timeout'},
        $sigmask || (),
    );

    my @events;
    for (0 .. $count) {
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
