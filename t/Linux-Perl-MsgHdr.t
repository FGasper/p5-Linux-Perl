#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;
use Test::Deep;

use Linux::Perl::MsgHdr;

use Data::Dumper;
sub _rightdump {
    local $Data::Dumper::Useqq = 1;
    local $Data::Dumper::Indent = 0;
    Dumper(@_);
}

my $cmsg = Linux::Perl::MsgHdr::pack_control( [ 1, 2, 'abcdef' ] );
my $lvl_type_data = pack( 'i! i! a8', 1, 2, 'abcdef' );
my $expected_cmsg = pack( 'L! a*', length(pack 'L!') + length($lvl_type_data), $lvl_type_data );
is(
    $cmsg,
    $expected_cmsg,
    'pack_control() - one value',
) or diag _rightdump($cmsg);

$cmsg = Linux::Perl::MsgHdr::pack_control( [ 1, 2, 'abcdef', 3, 4, 'ghijk' ] );

my $ltd2 = pack( 'i! i! a8', 3, 4, 'ghijk' );
is(
    $cmsg,
    join(
        q<>,
        $expected_cmsg,
        pack( 'L! a*', length(pack 'L!') + length($ltd2), $ltd2 ),
    ),
    'pack_control() - two values',
) or diag _rightdump($cmsg);

#----------------------------------------------------------------------

my %pack_opts = (
    name => \'123123',
    iov => [ \'abcdefg', \'hijklmnop' ],
    control => [ -1, -2, \'3456789' ],
);

my $pieces_ar = Linux::Perl::MsgHdr::pack_msghdr(%pack_opts);

is(
    ${ $pieces_ar->[0] },
    pack(
        'P L! P L! P L! x[I!]',

        ${ $pack_opts{'name'} },
        length ${ $pack_opts{'name'} },

        ${ $pieces_ar->[1] },
        0 + @{ $pack_opts{'iov'} },

        ${ $pieces_ar->[2] },
        length( pack 'L!i!i!' ) + length ${ $pack_opts{'control'}[2] },
    ),
    'main msghdr pack',
);

is(
    ${ $pieces_ar->[1] },
    pack(
        'P L! P L!',

        ${ $pack_opts{'iov'}[0] },
        length ${ $pack_opts{'iov'}[0] },

        ${ $pack_opts{'iov'}[1] },
        length ${ $pack_opts{'iov'}[1] },
    ),
    'iov pack',
);

is(
    ${ $pieces_ar->[2] },
    pack(
        'L! i! i!',
        length( pack 'L!i!i!' ) + length ${ $pack_opts{'control'}[2] },
        @{ $pack_opts{'control'} }[ 0, 1 ],
    ) . ${ $pack_opts{'control'}[2] },
    'control pack',
);

#----------------------------------------------------------------------

my %shrink_opts = (
    name => \do { my $v = "\0" x 256 },
    iov => [ \do { my $v = "\0" x 12 }, \do { my $v = "\0" x 200 } ],
    control => [ 0, 0, \do { my $v = "\0" x 256 } ],
);

Linux::Perl::MsgHdr::shrink_opt_strings(
    @$pieces_ar,
    %shrink_opts,
);

cmp_deeply(
    \%shrink_opts,
    {
        name => \do { "\0" x length ${ $pack_opts{'name'} } },
        iov => [
            \do { "\0" x length ${ $pack_opts{'iov'}[0] } },
            \do { "\0" x length ${ $pack_opts{'iov'}[1] } },
        ],
        control => [ -1, -2, \'3456789' ],
    },
    'shrink_opt_strings shrinks iov & name and restores control data as expected',
);

done_testing();

1;
