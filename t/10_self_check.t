use strict;
use warnings;
use Test::More tests => 2;
use FindBin;
use Parse::LocalDistribution;

for my $fork (0..1) {
  local $Parse::PMFile::FORK = $fork;
  my $p = Parse::LocalDistribution->new;
  my $provides = $p->parse("$FindBin::Bin/../");

  ok $provides && $provides->{'Parse::LocalDistribution'}{version} eq $Parse::LocalDistribution::VERSION, "version is correct";

  note explain $provides;
}
