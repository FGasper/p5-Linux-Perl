package Linux::Perl::timerfd::x86_64;

use strict;
use warnings;

use parent 'Linux::Perl::eventfd';

use constant {
    NR_timerfd_create  => 456,
    NR_timerfd_settimer  => 567,
    NR_timerfd_gettimer  => 678,
};

1;
