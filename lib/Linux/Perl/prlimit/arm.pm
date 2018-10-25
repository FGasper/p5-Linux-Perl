package Linux::Perl::prlimit::arm;

use strict;
use warnings;

use parent 'Linux::Perl::prlimit';

use constant {
    _NR_prlimit64 => 340,
};

1;
