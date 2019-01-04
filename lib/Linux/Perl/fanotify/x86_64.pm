package Linux::Perl::fanotify::x86_64;

use strict;
use warnings;

use parent qw( Linux::Perl::fanotify );

use constant {
    NR_fanotify_init => 300,
    NR_fanotify_mark => 301,
};

1;
