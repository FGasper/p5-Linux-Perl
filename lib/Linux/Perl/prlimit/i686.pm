package Linux::Perl::prlimit::i686;

use strict;
use warnings;

use parent 'Linux::Perl::prlimit';

use constant {
    NR_prlimit64 => 340,
};

1;
