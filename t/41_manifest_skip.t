use strict;
use warnings;
use FindBin;
use Test::More;
use File::Path;
use Parse::LocalDistribution;

my $pid = $$;
my $dir = "$FindBin::Bin/fake";
$dir =~ s|\\|/|g;
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
  {
    open my $fh, '>', "$dir/lib/ParseLocalDistTest2.pm" or die "failed to open a temp file: $!";
    print $fh "package " . "ParseLocalDistTest2;\n";
    print $fh "our \$VERSION = '0.02';\n";
    print $fh "1;\n";
    close $fh;
  }
  {
    open my $fh, '>', "$dir/MANIFEST.SKIP" or die "failed to open a temp file: $!";
    print $fh "ParseLocalDistTest2\n";
    close $fh;
  }
};
plan skip_all => $@ if $@;

plan tests => 2;

my $p = Parse::LocalDistribution->new;
my $provides = $p->parse($dir);
ok $provides && $provides->{ParseLocalDistTest}{version} eq '0.01', "correct version";
ok $provides && !$provides->{ParseLocalDistTest2}, "ParseLocalDistTest2 is ignored";
note explain $provides;
note explain $p;

END {
  if (-d $dir && $pid eq $$) {
    rmtree $dir;
  }
}
