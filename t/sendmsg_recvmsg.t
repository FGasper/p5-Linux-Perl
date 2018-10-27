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

#----------------------------------------------------------------------

pipe my $r, my $w;

$control_ar = [
    Socket::SOL_SOCKET(),
    Socket::SCM_RIGHTS(),
    \pack( 'I!*', fileno($r), fileno($w) ),
];

Linux::Perl::sendmsg->sendmsg(
    fd => fileno($yang),
    iov => [ \do { 'a' .. 'z' } ],
    control => $control_ar,
);

$data_in = "\0" x 1024;
$control_in = [ \do { my $v = "\0" x 12 } ];

setsockopt( $yang, Socket::SOL_SOCKET(), Socket::SO_PASSCRED(), 1 );

$bytes = Linux::Perl::recvmsg->recvmsg(
    fd => fileno($yin),
    iov => [ \$data_in ],
    control => $control_in,
);

is_deeply(
    [ @{$control_in}[0, 1] ],
    [ Socket::SOL_SOCKET(), Socket::SCM_RIGHTS() ],
    'control first two values',
);

my ($rfd, $wfd) = unpack 'I!*', ${ $control_in->[2] };
open my $r2, '<&=', $rfd;
open my $w2, '>&=', $wfd;

is_deeply(
    [ stat $r2 ],
    [ stat $r ],
    'duplicated read filehandle matches original',
);

is_deeply(
    [ stat $w2 ],
    [ stat $w ],
    'duplicated write filehandle matches original',
);

syswrite( $w, 'a' );
sysread( $r2, my $buf, 1 );
is( $buf, 'a', 'send from original write to duplicated read' );

syswrite( $w2, 'z' );
sysread( $r, $buf, 1 );
is( $buf, 'z', 'send from duplicated write to original read' );

done_testing();
