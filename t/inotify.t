#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;
use lib "$FindBin::Bin/lib";
use LP_EnsureArch;

LP_EnsureArch::ensure_support('inotify');

use File::Temp;

use Test::More;
use Test::Deep;
use Test::FailWarnings -allow_deps => 1;
use Test::SharedFork;

use Socket;

use Linux::Perl::inotify;

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::inotify';
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

    my $dir = File::Temp::tempdir( CLEANUP => 1 );

    my $inotify = $class->new( flags => [ 'NONBLOCK' ] );

    my $wd = $inotify->add( path => $dir, events => [ 'ALL_EVENTS' ] );

    $inotify->read();

    ok( $!{'EAGAIN'}, 'EAGAIN when a non-blocking inotify does empty read()' );

    do { open my $wfh, '>', "$dir/thefile" };

    chmod 0765, $dir;   # a quasi-nonsensical mode

    unlink "$dir/thefile";
    rmdir $dir;

    my @events = $inotify->read();

    cmp_deeply(
        \@events,
        [
            {
                wd => $wd,
                cookie => 0,
                events => $inotify->EVENT_NUMBER()->{'CREATE'},
                name => 'thefile',
            },
            {
                wd => $wd,
                cookie => 0,
                events => $inotify->EVENT_NUMBER()->{'OPEN'},
                name => 'thefile',
            },
            {
                wd => $wd,
                cookie => 0,
                events => $inotify->EVENT_NUMBER()->{'ATTRIB'} | $inotify->EVENT_NUMBER()->{'ISDIR'},
                name => q<>,
            },
            {
                wd => $wd,
                cookie => 0,
                events => $inotify->EVENT_NUMBER()->{'DELETE'},
                name => 'thefile',
            },
        ],
        'create chmod, unlink, rmdir events',
    ) or diag explain \@events;

    return;
}

done_testing();
