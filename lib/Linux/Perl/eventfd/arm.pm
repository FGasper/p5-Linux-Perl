package Linux::Perl::eventfd::arm;

use strict;
use warnings;

use parent 'Linux::Perl::eventfd';

use Linux::Perl::Constants::arm;

use constant {
    NR_eventfd  => 351,
    NR_eventfd2 => 356,
};

*flag_CLOEXEC = *Linux::Perl::Constants::arm::flag_CLOEXEC;
*flag_NONBLOCK = *Linux::Perl::Constants::arm::flag_NONBLOCK;

1;
