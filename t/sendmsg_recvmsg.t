#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

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
    \pack( 'I!*', $$, $>, (split m< >, $) )[0] ),
];

Linux::Perl::sendmsg->sendmsg(
    fd => fileno($yin),
    iov => [ \$data1, \$data2 ],
    control => $control_ar,
);

my $data_in = "\0" x 1024;
my $control_in = [ \do { my $v = "\0" x 12 } ];

setsockopt( $yang, Socket::SOL_SOCKET(), Socket::SO_PASSCRED(), 1 );

my $bytes = Linux::Perl::recvmsg->recvmsg(
    fd => fileno($yang),
    iov => [ \$data_in ],
    control => $control_in,
);

is(
    substr( $data_in, 0, $bytes ),
    join( q<>, 'a' .. 'z', 0 .. 9 ),
    'payload received',
) or diag sprintf('%v.02x', $data_in );

is_deeply(
    $control_in,
    [
        Socket::SOL_SOCKET(),
        Socket::SCM_CREDENTIALS(),
        \pack( 'I!*', $$, $>, (split m< >, $) )[0] ),
    ],
    'control received',
) or diag sprintf('%v.02x', ${ $control_in->[2] });

done_testing();
