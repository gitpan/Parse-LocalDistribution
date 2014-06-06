use strict;
use warnings;
use FindBin;
use Test::More;
use File::Path;
use File::Temp qw/tempdir/;
use Parse::LocalDistribution;

my $pid = $$;
my $dir;
eval {
  $dir = tempdir();
  for ($dir, "$dir/lib") {
    unless (-d $_) {
      mkpath $_ or die "failed to create a temporary directory: $_ $!";
    }
  }
  {
    open my $fh, '>', "$dir/lib/ParseLocalDistTest.pm" or die "failed to open a temp file: $!";
    print $fh "package " . "ParseLocalDistTest;\n";
    print $fh "our \$VERSION = '0.01';\n";
    print $fh "1;\n";
    close $fh;
  }
};
plan skip_all => $@ if $@;

plan tests => 1 * 2;

for my $fork (0..1) {
  local $Parse::PMFile::FORK = $fork;
  my $p = Parse::LocalDistribution->new;
  my $provides = $p->parse($dir);
  ok $provides && $provides->{ParseLocalDistTest}{version} eq '0.01', "correct version";
  note explain $provides;
}

END {
  if ($dir && -d $dir && $pid eq $$) {
    rmtree $dir;
  }
}
