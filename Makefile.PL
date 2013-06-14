use strict;
use warnings;
use ExtUtils::MakeMaker;

my %params = (
    NAME          => 'Parse::LocalDistribution',
    AUTHOR        => 'Kenichi Ishigaki <ishigaki@cpan.org>',
    VERSION_FROM  => 'lib/Parse/LocalDistribution.pm',
    ABSTRACT_FROM => 'lib/Parse/LocalDistribution.pm',
    LICENSE       => 'perl',
    PREREQ_PM     => {
        'List::Util' => 0,
        'Parse::CPAN::Meta' => '0',
        'Parse::PMFile' => '0.03',
    },
    BUILD_REQUIRES => {
        'File::Path' => 0,
        'Test::More'          => '0.47',
        'Test::UseAllModules' => '0.10',
    },
    META_MERGE => {
        resources => {
            repository => 'https://github.com/charsbar/Parse-LocalDistribution',
        },
    },
);

my $eumm = $ExtUtils::MakeMaker::VERSION;
delete $params{LICENSE}          if $eumm < 6.31;
delete $params{META_MERGE}       if $eumm < 6.46;

if ($eumm < 6.5503 && $params{BUILD_REQUIRES}) {
    $params{PREREQ_PM} = {
        %{ $params{PREREQ_PM}      || {} },
        %{ $params{BUILD_REQUIRES} },
    };
    delete $params{BUILD_REQUIRES};
}

WriteMakefile(%params);
