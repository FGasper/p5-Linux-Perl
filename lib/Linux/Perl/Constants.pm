package Linux::Perl::Constants;

use strict;
use warnings;

our $ARCHITECTURE;

sub get_architecture_name {
    return $ARCHITECTURE ||= do {
        require Config;
        Config->import();

        my $name = $Config::Config{'archname'};
        my $dash_at = index($name, '-');
        if ($dash_at != -1) {
            substr($name, $dash_at) = q<>;
        }

        $name;
    };
}

1;
