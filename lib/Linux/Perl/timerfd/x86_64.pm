package Linux::Perl::timerfd::x86_64;

use strict;
use warnings;

use parent 'Linux::Perl::eventfd';

use constant {
    NR_timerfd_create  => 456,
    NR_timerfd_settime  => 567,
    NR_timerfd_gettime  => 678,
};

1;
