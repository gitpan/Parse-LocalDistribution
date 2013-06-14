use strict;
use warnings;
use FindBin;
use Test::More;
use File::Path;
use Parse::LocalDistribution;

my $pid = $$;
my $dir = "$FindBin::Bin/fake";
eval {
  unless (-d $dir) {
    mkdir $dir or die "failed to create a temporary directory: $!";
    mkdir "$dir/lib" or die "failed to create a temporary directory: $!";
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

plan tests => 1;

my $p = Parse::LocalDistribution->new;
my $provides = $p->parse($dir);
ok $provides && $provides->{ParseLocalDistTest}{version} eq '0.01', "correct version";
note explain $provides;

END {
  if (-d $dir && $pid eq $$) {
    rmtree $dir;
  }
}
