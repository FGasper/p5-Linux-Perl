package Linux::Perl::inotify;

use strict;
use warnings;

use Linux::Perl;
use Linux::Perl::Constants::Fcntl;
use Linux::Perl::EasyPack;
use Linux::Perl::ParseFlags;

*_flag_CLOEXEC = \*Linux::Perl::Constants::Fcntl::flag_CLOEXEC;
*_flag_NONBLOCK = \*Linux::Perl::Constants::Fcntl::flag_NONBLOCK;

use constant EVENT_NUMBER => {
    ACCESS => 1,
    MODIFY => 2,
    ATTRIB => 4,
    CLOSE_WRITE => 8,
    CLOSE_NOWRITE => 16,
    OPEN => 32,
    MOVED_FROM => 64,
    MOVED_TO => 128,
    CREATE => 256,
    DELETE => 512,
    DELETE_SELF => 1024,
    MOVE_SELF => 2048,

    UNMOUNT => 0x2000,
    Q_OVERFLOW => 0x4000,
    IGNORED => 0x8000,
    ISDIR => 0x40000000,
};

use constant _shorthand_event_num => {
    CLOSE => EVENT_NUMBER()->{'CLOSE_WRITE'} | EVENT_NUMBER()->{'CLOSE_NOWRITE'},
    MOVE => EVENT_NUMBER()->{'MOVED_FROM'} | EVENT_NUMBER()->{'MOVED_TO'},

    ALL_EVENTS => do {
        my $num = 0;
        $num |= $_ for values %{ EVENT_NUMBER() };
        $num;
    },
};

use constant _event_opts => {
    ONLYDIR => 0x01000000,
    DONT_FOLLOW => 0x02000000,
    EXCL_UNLINK => 0x04000000,
    MASK_CREATE => 0x10000000,
    MASK_ADD => 0x20000000,
    ONESHOT => 0x80000000,
};

sub new {
    my ($class, %opts) = @_;

    if (!$class->can('NR_inotify_init')) {
        require Linux::Perl::ArchLoader;
        $class = Linux::Perl::ArchLoader::get_arch_module($class);
    }

    my $flags = Linux::Perl::ParseFlags::parse( $class, $opts{'flags'} );

    my $fn = 'NR_inotify_init';
    $fn .= '1' if $flags;

    my $fd = Linux::Perl::call(
        $class->$fn(),
        $flags,
    );

    local $^F = 1000 if $flags & _flag_CLOEXEC();

    open my $fh, '+<&=', $fd;

    return bless [$fd, $fh], $class;
}

my ($inotify_keys_ar, $inotify_pack, $inotify_sizeof);
BEGIN {
    ($inotify_keys_ar, $inotify_pack) = Linux::Perl::EasyPack::split_pack_list(
        wd => 'i!',     #int
        events => 'L',  #uint32_t
        cookie => 'L',  #uint32_t
        name => 'L/a',  #uint32_t & char[]
    );

    $inotify_sizeof = length pack $inotify_pack;
}

sub read {
    my ($self) = @_;

    my @events;

    my $res = sysread $self->[1], my $buf, 65536;

    if (defined $res) {
        while (my @els = unpack $inotify_pack, $buf) {
            my %evt;
            @evt{ @$inotify_keys_ar } = @els;

            substr( $buf, 0, $inotify_sizeof + length $els[-1] ) = q<>;

            $evt{'name'} =~ tr<\0><>d if $evt{'name'};

            push @events, \%evt;
        }
    }

    return @events;
}

sub add {
    my ($self, %opts) = @_;

    my $path = $opts{'path'};
    if (!defined $path || !length $path) {
        die 'Need path!';
    }

    my $events_mask = Linux::Perl::EventFlags::events_flags_to_num(
        $opts{'events'},
        EVENT_NUMBER(),
        _shorthand_event_num(),
        _event_opts(),
    );

    return Linux::Perl::call(
        $self->NR_inotify_add_watch(),
        0 + $self->[0],
        $path,
        0 + $events_mask,
    );
}

sub remove {
    my ($self, $wd) = @_;

    Linux::Perl::call(
        $self->NR_inotify_rm_watch(),
        0 + $self->[0],
        0 + $wd,
    );

    return $self;
}

#----------------------------------------------------------------------

package Linux::Perl::EventFlags;

sub events_flags_to_num {
    my ($input_ar, @names_to_nums) = @_;

    my $mask = 0;

  EVENT:
    for my $evt (@$input_ar) {
        for my $name_to_num_hr (@names_to_nums) {
            my $num = $name_to_num_hr->{$evt} or next;
            $mask |= $num;
            next EVENT;
        }

        die "Unknown event or flag: $evt";
    }

    return $mask;
}

1;
