use strict;
use warnings;
use Test::More tests => 1;
use FindBin;
use Parse::LocalDistribution;

my $p = Parse::LocalDistribution->new;
my $provides = $p->parse("$FindBin::Bin/../");

ok $provides && $provides->{'Parse::LocalDistribution'}{version} eq $Parse::LocalDistribution::VERSION, "version is correct";

note explain $provides;
