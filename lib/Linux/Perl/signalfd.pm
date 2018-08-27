package Linux::Perl::signalfd;

use strict;
use warnings;

use parent qw( Linux::Perl::Base::BitsTest );

use Linux::Perl;
use Linux::Perl::EasyPack;
use Linux::Perl::ParseFlags;
use Linux::Perl::SigSet;
use Linux::Perl::Constants::Fcntl;

*_flag_CLOEXEC = \*Linux::Perl::Constants::Fcntl::flag_CLOEXEC;
*_flag_NONBLOCK = \*Linux::Perl::Constants::Fcntl::flag_NONBLOCK;

use constant _sfd_siginfo_size => 128;

#----------------------------------------------------------------------

sub new {
    my ($class, %opts) = @_;

    my $arch_module = $class->can('NR_signalfd') && $class;
    $arch_module ||= do {
        require Linux::Perl::ArchLoader;
        Linux::Perl::ArchLoader::get_arch_module($class);
    };

    my $flags = Linux::Perl::ParseFlags::parse( $class, $opts{'flags'} );

    my $fd = _call_signalfd( $arch_module, -1, $flags, $opts{'signals'} );

    local $^F = 1000 if $flags & _flag_CLOEXEC();

    open my $fh, '+<&=', $fd;

    return bless [$fd, $fh], $arch_module;
}

#----------------------------------------------------------------------

sub fileno { return $_[0][0]; }

#----------------------------------------------------------------------

my ($sfd_siginfo_keys_ar, $sfd_siginfo_pack);

BEGIN {
    ($sfd_siginfo_keys_ar, $sfd_siginfo_pack) = Linux::Perl::EasyPack::split_pack_list(
        signo => 'L',
        errno => 'l',
        code => 'l',
        pid => 'L',
        uid => 'L',
        fd => 'l',
        tid => 'L',
        band => 'L',
        overrun => 'L',
        trapno => 'L',
        status => 'l',
        int => 'l',
        ptr => __PACKAGE__->_PACK_u64(),
        utime => __PACKAGE__->_PACK_u64(),
        stime => __PACKAGE__->_PACK_u64(),
        addr => __PACKAGE__->_PACK_u64(),
        addr_lsb => 'S',
    );
}

sub read {
    my ($self) = @_;

    return undef if !sysread( $self->[1], my $buf, _sfd_siginfo_size() );

    my %result;
    @result{ @$sfd_siginfo_keys_ar } = unpack $sfd_siginfo_pack, $buf;

    return \%result;
}

#----------------------------------------------------------------------

sub set_signals {
    my ($self, @signals) = @_;

    _call_signalfd(
        $self,
        $self->[0],
        0,
        \@signals,
    );

    return $self;
}

sub _call_signalfd {
    my ($arch_module, $fd, $flags, $signals_ar) = @_;

    my $sigmask = Linux::Perl::SigSet::from_list( @$signals_ar );

    my $call_name = 'NR_signalfd';
    $call_name .= '4' if $flags;

    $fd = Linux::Perl::call(
        $arch_module->$call_name(),
        $fd,
        $sigmask,
        length $sigmask,
        0 + $flags,
    );

    return $fd;
}

1;
