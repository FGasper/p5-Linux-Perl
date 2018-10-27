#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;
use Test::Deep;

use Linux::Perl::MsgHdr;

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
    join(
        q<>,

        pack('P', ${ $pack_opts{'iov'}[0] }),
        pack('L!', length ${ $pack_opts{'iov'}[0] }),

        pack('P', ${ $pack_opts{'iov'}[1] }),
        pack('L!', length ${ $pack_opts{'iov'}[1] }),
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
    'shrink_opt_strings shrinks and restores control data as expected',
);

done_testing();

1;
