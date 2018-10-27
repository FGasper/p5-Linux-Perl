#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use Linux::Perl::sendmsg;
use Linux::Perl::recvmsg;

use Socket;

socketpair my $yin, my $yang, Socket::AF_UNIX, Socket::SOCK_DGRAM, 0;

my $data1 = join( q<>, 'a' .. 'z' );
my $data2 = join( q<>, 0 .. 9 );

my $control_ar = [
    Socket::SOL_SOCKET(),
    Socket::SCM_CREDENTIALS(),
    pack( 'I!*', $$, $>, split( m< >, $) ) ),
];

Linux::Perl::sendmsg(
    fd => fileno $yin,
    iovec => [ \$data1, \$data2 ],
    control => $control_ar,
);

my $data_in = "\0" x 1024;
my $control_in = [ "\0" x 512 ];

Linux::Perl::recvmsg(
    fd => fileno $yang,
    iovec => [ \$data_in ],
    control => $control_in,
);

is( $data_in, join( q<>, 'a' .. 'z', 0 .. 9 ), 'payload received' );
is_deeply(
    $control_in,
    $control_ar,
    'control received',
);

done_testing();
