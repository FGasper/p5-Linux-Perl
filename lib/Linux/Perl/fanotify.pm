package Linux::Perl::fanotify;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Linux::Perl::fanotify

=head1 SYNOPSIS

TBD

=head1 DESCRIPTION

C<fanotify(7)> is a prospective successor to C<inotify(7)> that provides
a more featureful framework for listening for filesystem events. It offers
some useful advantages over inotify but, as of this writing, does not
support all features that the older framework provides.

This module is an attempt at a Perl interface to this new framework.
It is B<highly> experimental; be sure to test thoroughly, and please report
any bugs that you find.

=cut

#----------------------------------------------------------------------

use Linux::Perl;
use Linux::Perl::Constants::Fcntl;
use Linux::Perl::EasyPack;
use Linux::Perl::ParseFlags;

use parent (
    'Linux::Perl::Base',
    'Linux::Perl::Base::Fileno',
);

*_flag_CLOEXEC = \*Linux::Perl::Constants::Fcntl::flag_CLOEXEC;
*_flag_NONBLOCK = \*Linux::Perl::Constants::Fcntl::flag_NONBLOCK;

use constant _flag_flags => ('CLOEXEC', 'NONBLOCK', 'UNLIMITED_QUEUE', 'UNLIMITED_MARKS', 'ENABLE_AUDIT');

use constant {
    AT_FDCWD => -100,   # should this be elsewhere?

    FANOTIFY_METADATA_VERSION => 3,

    FAN_CLASS_CONTENT => 4,
    FAN_CLASS_PRE_CONTENT => 8,

    FAN_MARK_ADD    => 0x00000001,
    FAN_MARK_REMOVE    => 0x00000002,
    FAN_MARK_FLUSH => 0x00000080,
    FAN_MARK_IGNORED_MASK => 0x00000020,

    FAN_ALLOW => 1,
    FAN_DENY => 2,
    FAN_AUDIT => 16,

    _add_remove_flag => {
        DONT_FOLLOW => 4,
        ONLYDIR => 8,
        MOUNT => 16,
    },

    _flag_UNLIMITED_QUEUE => 16,
    _flag_UNLIMITED_MARKS => 32,
    _flag_ENABLE_AUDIT => 64,

    EVENT => {
        ACCESS => 1,
        MODIFY => 2,
        CLOSE_WRITE => 8,
        CLOSE_NOWRITE => 16,
        CLOSE => 24,    # convenience
        OPEN => 32,
        OPEN_EXEC => 0x1000,
        Q_OVERFLOW => 0x4000,
        OPEN_PERM => 0x10000,
        ACCESS_PERM => 0x20000,
        ONDIR => 0x40000000,
        EVENT_ON_CHILD => 0x08000000,
    },

    _flag_LARGEFILE => 32768,
    _flag_APPEND => 1024,
    _flag_DSYNC => 4096,
    _flag_NOATIME => 262144,
    _flag_SYNC => 1048576 | 4096,
};

my ($fanotify_keys_ar, $fanotify_pack, $fanotify_sizeof);
BEGIN {
    ($fanotify_keys_ar, $fanotify_pack) = Linux::Perl::EasyPack::split_pack_list(
        q<> => 'xxxx',  # u32
        vers => 'C',    # u8
        q<> => 'x',     # u8
        q<> => 'xx',    # u16
        mask => 'Q',    # u64
        fd => 'l',      # s32
        pid => 'l',     # s32
    );

    $fanotify_sizeof = length pack $fanotify_pack;
}

=head2 I<CLASS>->new( %OPTS )

Returns a new instance. %OPTS are:

=over

=item * C<notification_class> - Optional, one of: C<PRE_CONTENT>, C<CONTENT>, C<NOTIF> (default).

=item * C<access> - One of: C<RDONLY>, C<WRONLY>, C<RDWR>.

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $nclass = $opts{'notification_class'} || 0;

    if ($nclass) {
        $nclass = $class->can("FAN_CLASS_$nclass") || do {
            die "Unknown notification class: '$nclass'!";
        };

        $nclass = $nclass->();
    }

    my $access_n = $opts{'access'} || do {
        die "Need 'access'!";
    };
    $access_n = Linux::Perl::Constants::Fcntl->can("mode_$access_n") || do {
        die "Unknown 'access': '$access_n'";
    };

    my $flags = Linux::Perl::ParseFlags::parse( $class, $opts{'flags'} );

    local $^F = 1000 if $flags & _flag_CLOEXEC();

    my $flag_flags = $nclass;

    for my $name ( _flag_flags() ) {
        my $val = $class->can("_flag_$name")->();
        if ($flags & $val) {
            $flag_flags |= $val;
            $flags ^= $val;
        }
    }

    $class = $class->_get_arch_module();

    my $fd = Linux::Perl::call(
        0 + $class->NR_fanotify_init(),
        0 + $flag_flags,
        0 + ($access_n->() | $flags),
    );

    open my $fh, '+<&=', $fd;

    return bless [$fd, $fh], $class;
}

=head2 I<OBJ>->add_mark( %OPTS )

Adds to the mark mask. Returns the OBJ. %OPTS are:

=over

=item C<events> - Arrayref, one or more of: C<ACCESS>, C<MODIFY>,
C<CLOSE_WRITE>, C<CLOSE_NOWRITE>, C<CLOSE>, C<OPEN>, C<Q_OVERFLOW>,
C<OPEN_PERM>, C<ACCESS_PERM>, C<ONDIR>, C<EVENT_ON_CHILD>.

=item C<flags> - Optional arrayref, zero or more of: C<DONT_FOLLOW>,
C<ONLYDIR>, C<MOUNT>.

=item C<pathname> - Optional, string.

=item C<fd> - Optional, one of: a filehandle, a file descriptor, or
C<.> (which indicates AT_FDCWD).

=back

See L<fanotify_mask(2)> for details about what the above do.

=cut

sub add_mark {
    my ($self, %opts) = @_;

    if ($opts{'flags'} && $opts{'flags'} & FAN_MARK_IGNORED_MASK) {
        die "Call add_ignore(), not add_mark() with FAN_MARK_IGNORED_MASK!";
    }

    return $self->_add_remove( \%opts, $self->FAN_MARK_ADD() );
}

sub _add_remove {
    my ($self, $opts_hr, $flags) = @_;

    my $fh = $opts_hr->{'fh'};

    if (ref $fh) {
        $fh = fileno $fh;
    }
    elsif (defined($fh) && '.' eq $fh) {
        $fh = AT_FDCWD;
    }

    if (defined $opts_hr->{'pathname'}) {
        if (0 == rindex($opts_hr->{'pathname'}, '/', 0)) {
            if ($fh) {
                die "Cannot give absolute 'pathname' and filehandle!";
            }
        }

        $opts_hr->{'pathname'} = "$opts_hr->{'pathname'}";
    }
    else {
        $opts_hr->{'pathname'} = 0;
    }

    Linux::Perl::call(
        0 + $self->NR_fanotify_mark(),
        0 + $self->[0],
        0 + ($flags | _compute_add_remove_flags($opts_hr)),
        0 + _compute_add_remove_mask($opts_hr),
        $fh ? (0 + $fh) : 0,
        $opts_hr->{'pathname'},
    );

    return $self;
}

sub _compute_add_remove_flags {
    my ($opts_hr) = @_;

    my $flags = 0;

    my $fd_flags = 0;

    if (my $flags_ar = $opts_hr->{'flags'}) {
        for my $fname ( @$flags_ar ) {
            my $num = __PACKAGE__->_add_remove_flag()->{$fname} || do {
                die "Unknown add/remove flag: '$fname'";
            };
            $flags |= $num->();
        }
    }

    return $flags;
}

sub _compute_add_remove_mask {
    my ($opts_hr) = @_;

    my $mask = 0;

    if (my $events_ar = $opts_hr->{'events'}) {
        for my $ename (@$events_ar) {
            my $num = EVENT()->{$ename} || do {
                die "Unknown event: '$ename'";
            };
            $mask |= $num;
        }
    }

    return $mask;
}

=head2 I<OBJ>->add_ignore( %OPTS )

Like C<add_mark()> but for the ignore mask.

=cut

sub add_ignore {
    my ($self, %opts) = @_;

    $opts{'flags'} ||= 0;
    $opts{'flags'} |= FAN_MARK_IGNORED_MASK;

    return $self->_add_remove( \%opts, $self->FAN_MARK_ADD() );
}

=head2 I<OBJ>->remove_mark( %OPTS )

The inverse of C<remove_mark()>.

=cut

sub remove_mark {
    my ($self, %opts) = @_;

    if ($opts{'flags'} && $opts{'flags'} & FAN_MARK_IGNORED_MASK) {
        die "Call remove_ignore(), not remove_mark() with FAN_MARK_IGNORED_MASK!";
    }

    return $self->_add_remove( \%opts, $self->FAN_MARK_REMOVE() );
}

=head2 I<OBJ>->remove_ignore( %OPTS )

The inverse of C<remove_ignore()>.

=cut

sub remove_ignore {
    my ($self, %opts) = @_;

    $opts{'flags'} ||= 0;
    $opts{'flags'} |= FAN_MARK_IGNORED_MASK;

    return $self->_add_remove( \%opts, $self->FAN_MARK_ADD() );
}

my $_checked_version;

sub allow {
    my ($self, $fd) = @_;

    return $self->_respond( $fd, FAN_ALLOW() );
}

sub allow_with_audit {
    my ($self, $fd) = @_;

    return $self->_respond( $fd, FAN_ALLOW() | FAN_AUDIT() );
}

sub deny {
    my ($self, $fd) = @_;

    return $self->_respond( $fd, FAN_DENY() );
}

sub deny_with_audit {
    my ($self, $fd) = @_;

    return $self->_respond( $fd, FAN_DENY() | FAN_AUDIT );
}

sub _respond {
    my ($self, $fd, $response) = @_;

    return syswrite( $self->[1], pack( 'lL', $fd, $response ) ) && 1;
}

sub read {
    my ($self) = @_;

    my @events;

    my $res = sysread $self->[1], my $buf, 65536;

    if (defined $res) {
        while (my @els = unpack $fanotify_pack, $buf) {
            my %evt;
            @evt{ @$fanotify_keys_ar } = @els;

            $_checked_version ||= do {
                if ($evt{'vers'} != FANOTIFY_METADATA_VERSION()) {
                    die sprintf( "'vers' (%s) mismatches 'FANOTIFY_METADATA_VERSION' (%d)!", $evt{'vers'}, FANOTIFY_METADATA_VERSION() );
                }

                1;
            };

            delete $evt{'vers'};

            substr( $buf, 0, $fanotify_sizeof + length $els[-1] ) = q<>;

            push @events, \%evt;

            # Perl 5.16 and previous choke with:
            #
            #   '/' must follow a numeric type in unpack
            #
            # » unless we avoid unpack() on an empty string.
            last if !$buf;
        }
    }

    return @events;
}

#----------------------------------------------------------------------

sub _flush {
    my ($self, $flags) = @_;

    Linux::Perl::call(
        0 + $self->NR_fanotify_mark(),
        0 + $self->[0],
        0 + $self->FAN_MARK_FLUSH() | $flags,
        0, 0, undef,
    );

    return $self;
}

sub flush_mount_marks {
    my ($self) = @_;

    return $self->_flush( $self->_add_remove_flag()->{'MOUNT'} );
}

sub flush_non_mount_marks {
    my ($self) = @_;

    return $self->_flush( 0 );
}

1;
