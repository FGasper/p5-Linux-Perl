package Linux::Perl::eventfd::x86_64;

use strict;
use warnings;

use parent 'Linux::Perl::eventfd';

use constant {
    NR_eventfd  => 284,
    NR_eventfd2 => 290,

    flag_SEMAPHORE => 1,
};

*flag_CLOEXEC = *Linux::Perl::Constants::x86_64::flag_CLOEXEC;
*flag_NONBLOCK = *Linux::Perl::Constants::x86_64::flag_NONBLOCK;

1;
