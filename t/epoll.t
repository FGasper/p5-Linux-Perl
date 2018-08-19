#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('epoll');

use File::Temp;

use Test::More;
use Test::Deep;
use Test::FailWarnings;
use Test::SharedFork;

use Linux::Perl::epoll;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::epoll';
            if (!$generic_yn) {
                require Linux::Perl::ArchLoader;
                $class = Linux::Perl::ArchLoader::get_arch_module($class);
            };

            _do_tests($class);
        };
        die if $@;
        exit;
    }
}

sub _do_tests {
    my ($class) = @_;

    note "Using class: $class (PID $$)";

    {
        my $epl = $class->new();
        my $fileno = $epl->[0];

        my $no_cloexec = `$^X -e'print readlink "/proc/self/fd/$fileno"'`;
        ok( !$no_cloexec, 'CLOEXEC by default' );

        local $^F = 1000;

        $epl = $class->new();
        $fileno = $epl->[0];

        $no_cloexec = `$^X -e'print readlink "/proc/self/fd/$fileno"'`;
        ok( $no_cloexec, 'no CLOEXEC if $^F is high' );

        $epl = $class->new( flags => ['CLOEXEC'] );
        $fileno = $epl->[0];

        $no_cloexec = `$^X -e'print readlink "/proc/self/fd/$fileno"'`;
        ok( !$no_cloexec, 'CLOEXEC if $^F is high but CLOEXEC is given' );
    }

    pipe( my $r, my $w );

    my $epl = $class->new();
    $epl->add( $r, events => ['IN'] );

    my @events = $epl->wait( maxevents => 1, timeout => 1 );

    cmp_deeply( \@events, [], 'no read events' ) or diag explain \@events;

    syswrite( $w, 'x' );

    @events = $epl->wait( maxevents => 1, timeout => 1 );

    cmp_deeply(
        \@events,
        [
            {
                events => [ 'IN' ],
                data => fileno($r),
            },
        ],
        'received an event',
    ) or diag explain @events;

    return;
}

done_testing();
