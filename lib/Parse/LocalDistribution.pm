package Parse::LocalDistribution;

use strict;
use warnings;
use Parse::PMFile;
use List::Util ();
use Parse::CPAN::Meta ();
use File::Spec;
use File::Find;
use Cwd ();

our $VERSION = '0.03';

sub new {
  my ($class, $root) = @_;
  $root ||= Cwd::cwd();
  bless {DISTROOT => $root, DIST => $root}, $class;
}

# adapted from PAUSE::mldistwatch#check_for_new
sub parse {
  my ($self, $root) = @_;
  if ($root) {
    $self->{DISTROOT} = $self->{DIST} = $root;
  }

  $self->_read_dist;
  $self->_extract_meta;
  $self->_examine_pms;
}

# from PAUSE::dist;
sub _read_dist {
  my $self = shift;
  # TODO: support absolute path
  my(@manifind) = $self->_find_files;
  my $manifound = @manifind;
  $self->{MANIFOUND} = \@manifind;
  my $dist = $self->{DIST};
  unless (@manifind){
    $self->_verbose(1,"NO FILES! in dist $dist?");
    return;
  }
  $self->_verbose(1,"Found $manifound files in dist $dist, first $manifind[0]\n");
}

# from PAUSE::dist;
sub _extract_meta {
  my $self = shift;

  my $dist = $self->{DIST};
  my @manifind = @{$self->{MANIFOUND}};

  my $json = List::Util::reduce { length $a < length $b ? $a : $b }
             grep !m|/t/|, grep m|/META\.json$|, @manifind;
  my $yaml = List::Util::reduce { length $a < length $b ? $a : $b }
             grep !m|/t/|, grep m|/META\.yml$|, @manifind;

  # META.json located only in a subdirectory should not precede
  # META.yml located in the top directory. (eg. Test::Module::Used 0.2.4)
  if ($json && $yaml && length($json) > length($yaml) + 1) {
    $json = '';
  }

  unless ($json || $yaml) {
    $self->{METAFILE} = "No META.yml or META.json found";
    $self->_verbose(1,"No META.yml or META.json in $dist");
    return;
  }

  for my $metafile ($json || $yaml) {
    my $metafile_abs = File::Spec->catfile($self->{DISTROOT}, $metafile);
    $metafile_abs =~ s|\\|/|g;
    if (-s $metafile_abs) {
      $self->{METAFILE} = $metafile;
      my $ok = eval {
        $self->{META_CONTENT} = Parse::CPAN::Meta->load_file($metafile_abs); 1
      };
      unless ($ok) {
        $self->_verbose(1,"Error while parsing $metafile: $@");
        $self->{META_CONTENT} = {};
        $self->{METAFILE} = "$metafile found but error "
                          . "encountered while loading: $@";
      }
    } else {
      $self->{METAFILE} = "Empty $metafile found, ignoring\n";
    }
  }
}

# from PAUSE::dist;
sub _examine_pms {
  my $self = shift;

  my $dist = $self->{DIST};

  my $pmfiles = $self->_filter_pms;
  my($meta,$provides,$indexingrule);
  if (my $version_from_meta_ok = $self->_version_from_meta_ok) {
    $meta = $self->{META_CONTENT};
    $provides = $meta->{provides};
    if (!$indexingrule && $provides && "HASH" eq ref $provides) {
      $indexingrule = 2;
    }
  }
  if (!$indexingrule && @$pmfiles) { # examine files
    $indexingrule = 1;
  }

  my %result;
  my $parser = Parse::PMFile->new($self->{META_CONTENT});
  if (0) {
  } elsif (1==$indexingrule) { # examine files
    for my $pmfile (@$pmfiles) {
      my $pmfile_abs = File::Spec->catfile($self->{DISTROOT}, $pmfile);
      $pmfile_abs =~ s|\\|/|g;
      if ($pmfile_abs =~ m|/blib/|) {
        $self->_verbose("Still a blib directory detected:
          dist[$dist]pmfile[$pmfile]
          ");
        next;
      }

      my $info = $parser->parse($pmfile_abs);

      $result{$_} = $info->{$_} for keys %$info;
    }
  } elsif (2==$indexingrule) { # a yaml with provides
    while (my($k,$v) = each %$provides) {
      $v->{infile} = "$v->{file}";
      my @stat = stat File::Spec->catfile($self->{DISTROOT}, $v->{file});
      if (@stat) {
        $v->{filemtime} = $stat[9];
      } else {
        $v->{filemtime} = 0;
      }
      unless (defined $v->{version}) {
        # 2009-09-23 get a bugreport due to
        # RKITOVER/MooseX-Types-0.20.tar.gz not
        # setting version for MooseX::Types::Util
        $v->{version} = "undef";
      }
      # going from a distro object to a package object
      # is only possible via a file object
      my $info = $parser->parse(File::Spec->catfile($self->{DISTROOT}, $v->{infile}));

      $result{$_} = $info->{$_} for keys %$info;
    }
  }

  return \%result;
}

# from PAUSE::dist;
sub _filter_pms {
  my($self) = @_;
  my @pmfile;

  # very similar code is in PAUSE::package::filter_ppps
  MANI: for my $mf ( @{$self->{MANIFOUND}} ) {
    next unless $mf =~ /\.pm(?:\.PL)?$/i;
    my($inmf) = $mf =~ m!^[^/]+/(.+)!; # go one directory down

    # skip "t" - libraries in ./t are test libraries!
    # skip "xt" - libraries in ./xt are author test libraries!
    # skip "inc" - libraries in ./inc are usually install libraries
    # skip "local" - somebody shipped his carton setup!
    # skip 'perl5" - somebody shipped her local::lib!
    # skip 'fatlib" - somebody shipped their  fatpack lib!
    next if $inmf =~ m!^(?:x?t|inc|local|perl5|fatlib)/!;

    if ($self->{META_CONTENT}){
      my $no_index = $self->{META_CONTENT}{no_index}
      || $self->{META_CONTENT}{private}; # backward compat
      if (ref($no_index) eq 'HASH') {
        my %map = (
          file => qr{\z},
          directory => qr{/},
        );
        for my $k (qw(file directory)) {
          next unless my $v = $no_index->{$k};
          my $rest = $map{$k};
          if (ref $v eq "ARRAY") {
            for my $ve (@$v) {
              $ve =~ s|/+$||;
              if ($inmf =~ /^$ve$rest/){
                $self->_verbose(1,"Skipping inmf[$inmf] due to ve[$ve]");
                next MANI;
              } else {
                $self->_verbose(1,"NOT skipping inmf[$inmf] due to ve[$ve]");
              }
            }
          } else {
            $v =~ s|/+$||;
            if ($inmf =~ /^$v$rest/){
              $self->_verbose(1,"Skipping inmf[$inmf] due to v[$v]");
              next MANI;
            } else {
              $self->_verbose(1,"NOT skipping inmf[$inmf] due to v[$v]");
            }
          }
        }
      } else {
        # noisy:
        # $self->_verbose(1,"no keyword 'no_index' or 'private' in META_CONTENT");
      }
    } else {
      # $self->_verbose(1,"no META_CONTENT"); # too noisy
    }
    push @pmfile, $mf;
  }
  $self->_verbose(1,"Finished with pmfile[@pmfile]\n");
  \@pmfile;
}

sub _version_from_meta_ok { Parse::PMFile::_version_from_meta_ok(@_) }
sub _verbose { Parse::PMFile::_verbose(@_) }

# instead of ExtUtils::Manifest::manifind()
# which only looks for files under the current directory.
sub _find_files {
  my $self = shift;

  my @files;

  my $root = $self->{DISTROOT};
  my $wanted = sub {
    my $name = $File::Find::name;
    return if -d $_;
    return if $name =~ m!/(?:\.(?:svn|git)|blib)/!; # too common
    my $rel = File::Spec->abs2rel($name, $root);
    $rel =~ s|\\|/|g;
    push @files, "./$rel";
  };

  File::Find::find(
    {wanted => $wanted, follow => 0, no_chdir => 1}, $root
  );

  return sort @files;
}

1;

__END__

=head1 NAME

Parse::LocalDistribution - parses local .pm files as PAUSE does

=head1 SYNOPSIS

    use Parse::LocalDistribution;

    local $Parse::PMFile::ALLOW_DEV_VERSION = 1;
    my $parser = Parse::LocalDistribution->new;
    my $provides = $parser->parse('.');

=head1 DESCRIPTION

This is a sister module of L<Parse::PMFile>. This module parses local .pm files (and a META file if any) in a specific (current if not specified) directory, and returns a hash reference that represents "provides" information (with some extra meta data). This is almost the same as L<Module::Metadata> does (which has been in Perl core since Perl 5.13.9). The main difference is the most of the code of this module is directly taken from the PAUSE code as of June 2013. If you need better compatibility to PAUSE, try this. If you need better performance, safety, or portability in general, L<Module::Metadata> may be a better and handier option (L<Parse::PMFile> (and thus L<Parse::LocalDistribution>) forks internally and actually evaluates code in the $VERSION line (in a Safe compartment), both of which may be problematic in some cases).

This module doesn't provide a feature to extract a distribution. If you are too lazy to implement it, L<CPAN::ParseDistribution> may be another good option.

=head1 METHODS

=head2 new

creates an object.

=head2 parse

may take a path to a local distribution, and return a hash reference that holds information for package(s) found in the directory.

=head1 SEE ALSO

Most part of this module is derived from PAUSE.

L<https://github.com/andk/pause>

The following distributions do similar parsing, though the results may differ sometimes.

L<Module::Metadata>, L<CPAN::ParseDistribution>

=head1 AUTHOR

Andreas Koenig E<lt>andreas.koenig@anima.deE<gt>

Kenichi Ishigaki, E<lt>ishigaki@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 1995 - 2013 by Andreas Koenig E<lt>andk@cpan.orgE<gt> for most of the code.

Copyright 2013 by Kenichi Ishigaki for some.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
