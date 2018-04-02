package LP_EnsureArch;

use Test::More;

use Module::Load;
use Linux::Perl::Constants;

use File::Spec;

sub ensure_support {
    my ($module) = @_;

    my $supported = ($^O eq 'linux');
    my $arch = Linux::Perl::Constants::get_architecture_name();

    $supported &&= do {
        my @path = ( 'Linux', 'Perl', $module, $arch );
        !!grep { -e File::Spec->catfile( $_, @path ) };
    };

    if (!$supported) {
        diag "Unsupported OS/architecture for “$module”: $^O/$arch";
        done_testing();
        exit;
    }

    return $arch;
}

1;
