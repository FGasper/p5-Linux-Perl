#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use LP_EnsureArch;

LP_EnsureArch::ensure_support('memfd');

use Linux::Perl::memfd;

my $memfd = Linux::Perl::memfd->new(
    flags => ['CLOEXEC', 'ALLOW_SEALING'],
    #huge_page_size => '64KB',
);

#----------------------------------------------------------------------
#my $GET_SEALS = 1024 + 10;
#stat "==== GET SEALS";
#my $seals = fcntl( $memfd, $GET_SEALS, 0 );
#diag "seals: $seals";

truncate( $memfd, 16 );

my $pid = fork or do {
    syswrite( $memfd, 'hahaha' );
    exit;
};

waitpid $pid, 0;

sysseek( $memfd, 0, 0 );

sysread( $memfd, my $buf, 16 );

$buf =~ tr<\0><>d;

is( $buf, 'hahaha', 'transfer across memfd' ) or diag explain $buf;

done_testing();
