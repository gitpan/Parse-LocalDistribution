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
    mkdir "$dir/inc" or die "failed to create a temporary directory: $!";
  }
  {
    open my $fh, '>', "$dir/lib/ParseLocalDistTest.pm" or die "failed to open a temp file: $!";
    print $fh "package " . "ParseLocalDistTest;\n";
    print $fh "our \$VERSION = '0.01';\n";
    print $fh "1;\n";
    close $fh;
  }
  {
    open my $fh, '>', "$dir/inc/ParseLocalDistInc.pm" or die "failed to open a temp file: $!";
    print $fh "package " . "ParseLocalInc;\n";
    print $fh "our \$VERSION = '0.02';\n";
    print $fh "1;\n";
    close $fh;
  }
  {
    open my $fh, '>', "$dir/META.json" or die "failed to open a temp file: $!";
    print $fh '{"abstract": "", "author": ["me"], "name": "ParseLocalDistTest", "no_index": {"directory": ["t", "inc"]}, "version": "0.01"}';
    close $fh;
  }
};
plan skip_all => $@ if $@;

plan tests => 2;

my $p = Parse::LocalDistribution->new;
my $provides = $p->parse($dir);
ok $provides && $provides->{ParseLocalDistTest}{version} eq '0.01', "correct version";
ok $provides && !$provides->{ParseLocalInc}, "TestParseLocalInc is ignored";
note explain $provides;
note explain $p;

END {
  if (-d $dir && $pid eq $$) {
    rmtree $dir;
  }
}
