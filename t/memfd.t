#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;
use Test::SharedFork;

use FindBin;
use lib "$FindBin::Bin/lib";

use LP_EnsureArch;

LP_EnsureArch::ensure_support('memfd');

use Linux::Perl::memfd;

#----------------------------------------------------------------------

for my $generic_yn ( 0, 1 ) {
    if ( my $pid = fork ) {
        waitpid $pid, 0;
        die if $?;
    }
    else {
        eval {
            my $class = 'Linux::Perl::memfd';
            if (!$generic_yn) {
                require Linux::Perl::ArchLoader;
                $class = Linux::Perl::ArchLoader::get_arch_module($class);
            };

            diag "----------- CLASS: $class -----------";

            _do_tests($class);
        };
        die if $@;
        exit;
    }
}

sub _do_tests {
    my ($class) = @_;

    my $memfd = $class->new(
        name => 'this is my name',
        flags => ['CLOEXEC', 'ALLOW_SEALING'],
        #huge_page_size => '64KB',
    );

    my $pid = fork or do {
        syswrite( $memfd, 'hahaha' );
        exit;
    };

    waitpid $pid, 0;

    sysseek( $memfd, 0, 0 );

    sysread( $memfd, my $buf, 16 );

    is( $buf, 'hahaha', 'transfer across memfd' ) or diag explain $buf;

    my $fileno = fileno $memfd;

    like(
        CORE::readlink("/proc/$$/fd/$fileno"),
        qr<memfd.*this is my name>,
        'given name is respected',
    );

    my $link = `$^X -e'print readlink("/proc/\$\$/fd/$fileno")'`;
    ok( !$link, 'CLOEXEC flag is respected' );

    undef $memfd;

    ok( !CORE::readlink("/proc/$$/fd/$fileno"), 'garbage-collect (CLOEXEC flag)' );

    #----------------------------------------------------------------------

    $memfd = $class->new();
    $fileno = fileno( $memfd );

    $link = `$^X -e'print readlink("/proc/\$\$/fd/$fileno")'`;
    ok( !$link, 'implicit CLOEXEC is respected' );

    undef $memfd;

    ok( !CORE::readlink("/proc/$$/fd/$fileno"), 'garbage-collect (implicit CLOEXEC)' );

    #----------------------------------------------------------------------

    {
        local $^F = 1000;

        my $memfd = $class->new( name => 'still alive' );
        $fileno = fileno($memfd);

        my $link = `$^X -e'print readlink("/proc/\$\$/fd/$fileno")'`;
        like( $link, qr<still alive>, 'non-CLOEXEC works' );
    }

    return;
}

done_testing();
