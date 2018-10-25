package Linux::Perl::prlimit::arm;

use strict;
use warnings;

use parent 'Linux::Perl::prlimit';

use constant {
    NR_prlimit64 => 369,
};

1;
