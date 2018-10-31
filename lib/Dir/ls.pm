package Dir::ls;

use strict;
use warnings;
use Carp 'croak';
use Exporter 'import';
use Fcntl 'S_ISDIR';
use File::Spec;
use File::stat;
use Path::ExpandTilde;
use Sort::filevercmp 'fileversort';
use Text::Glob 'glob_to_regex';

use sort 'stable';

our $VERSION = '0.006';

our @EXPORT = 'ls';

sub ls {
  my ($dir, $options);
  if (ref $_[0] eq 'HASH') {
    ($options) = @_;
  } else {
    ($dir, $options) = @_;
  }
  $dir = '.' unless defined $dir and length $dir;
  $options ||= {};

  $dir = expand_tilde($dir); # do homedir expansion

  opendir my $dh, $dir or croak "Failed to open directory '$dir': $!";
  my @entries = readdir $dh;
  closedir $dh or croak "Failed to close directory '$dir': $!";

  my $show_all = !!($options->{a} or $options->{all} or $options->{f});
  my $show_almost_all = !!($options->{A} or $options->{'almost-all'});
  my $skip_backup = !!($options->{B} or $options->{'ignore-backups'});
  my $hide_pattern = defined $options->{hide} ? glob_to_regex($options->{hide}) : undef;
  my $ignore_glob = defined $options->{I} ? $options->{I} : $options->{ignore};
  my $ignore_pattern = defined $ignore_glob ? glob_to_regex($ignore_glob) : undef;
  @entries = grep {
    ($show_all ? 1 : $show_almost_all ? ($_ ne '.' and $_ ne '..') :
      (!m/^\./ and defined $hide_pattern ? !m/$hide_pattern/ : 1))
    and ($skip_backup ? !m/~\z/ : 1)
    and (defined $ignore_pattern ? !m/$ignore_pattern/ : 1)
  } @entries;

  my $sort = $options->{sort} || '';
  if ($options->{U} or $options->{f} or $sort eq 'none') {
    $sort = 'U';
  } elsif ($options->{v} or $sort eq 'version') {
    $sort = 'v';
  } elsif ($options->{S} or $sort eq 'size') {
    $sort = 'S';
  } elsif ($options->{X} or $sort eq 'extension') {
    $sort = 'X';
  } elsif ($options->{t} or $sort eq 'time') {
    $sort = 't';
  } elsif ($options->{c}) {
    $sort = 'c';
  } elsif ($options->{u}) {
    $sort = 'u';
  } elsif (defined $options->{sort}) {
    croak "Unknown sort option '$sort'; must be 'none', 'size', 'time', 'version', or 'extension'";
  }

  my %stat;

  unless ($sort eq 'U') {
    if ($sort eq 'v') {
      @entries = fileversort @entries;
    } else {
      {
        # pre-sort by collation
        use locale;
        @entries = sort @entries;
      }

      if ($sort eq 'S') {
        my @sizes = map { _stat($_, $dir, \%stat)->size } @entries;
        @entries = @entries[sort { $sizes[$b] <=> $sizes[$a] } 0..$#entries];
      } elsif ($sort eq 'X') {
        my @extensions = map { _ext_sorter($_) } @entries;
        use locale;
        @entries = @entries[sort { $extensions[$a] cmp $extensions[$b] } 0..$#entries];
      } elsif ($sort eq 't') {
        my @mtimes = map { _stat($_, $dir, \%stat)->mtime } @entries;
        @entries = @entries[sort { $mtimes[$a] <=> $mtimes[$b] } 0..$#entries];
      } elsif ($sort eq 'c') {
        my @ctimes = map { _stat($_, $dir, \%stat)->ctime } @entries;
        @entries = @entries[sort { $ctimes[$a] <=> $ctimes[$b] } 0..$#entries];
      } elsif ($sort eq 'u') {
        my @atimes = map { _stat($_, $dir, \%stat)->atime } @entries;
        @entries = @entries[sort { $atimes[$a] <=> $atimes[$b] } 0..$#entries];
      }
    }

    @entries = reverse @entries if $options->{r} or $options->{reverse};

    if ($options->{'group-directories-first'}) {
      my ($dirs, $files) = ([], []);
      push @{S_ISDIR(_stat($_, $dir, \%stat)->mode) ? $dirs : $files}, $_ for @entries;
      @entries = (@$dirs, @$files);
    }
  }

  return @entries;
}

sub _stat {
  my ($entry, $dir, $cache) = @_;
  return $cache->{$entry} if exists $cache->{$entry};
  my $path = File::Spec->catfile($dir, $entry);
  my $stat = stat $path;
  unless ($stat) { # try as a subdirectory
    $path = File::Spec->catdir($dir, $entry);
    $stat = stat $path;
  }
  croak "Failed to stat '$path': $!" unless $stat;
  return $cache->{$entry} = $stat;
}

sub _ext_sorter {
  my ($entry) = @_;
  my ($ext) = $entry =~ m/(\.[^.]*)\z/;
  $ext = '' unless defined $ext;
  return $ext;
}

1;

=head1 NAME

Dir::ls - List the contents of a directory

=head1 SYNOPSIS

  use Dir::ls;
  
  print "$_\n" for ls; # defaults to current working directory
  
  print "$_: ", -s "/foo/bar/$_", "\n" for ls '/foo/bar', {all => 1, sort => 'size'};

=head1 DESCRIPTION

Provides the function L</"ls">, which returns the contents of a directory in a
similar manner to the GNU coreutils command L<ls(1)>.

=head1 FUNCTIONS

=head2 ls

  my @contents = ls $dir, \%options;

Takes a directory path and optional hashref of options, and returns a list of
items in the directory. Home directories represented by C<~> will be expanded
by L<Path::ExpandTilde>. If no directory path is passed, the current working
directory will be used. Like in L<ls(1)>, the returned names are relative to
the passed directory path, so if you want to use a filename (such as passing it
to C<open> or C<stat>), you must prefix it with the directory path, with C<~>
expanded if present.

  # Check the size of a file in current user's home directory
  my @contents = ls '~';
  say -s "$ENV{HOME}/$contents[0]";

By default, hidden files and directories (those starting with C<.>) are
omitted, and the results are sorted by name according to the current locale
(see L<perllocale> for more information).

Accepts the following options:

=over 2

=item a

=item all

Include hidden files and directories.

=item A

=item almost-all

Include hidden files and directories, but not C<.> or C<..>.

=item B

=item ignore-backups

Omit files and directories ending in C<~>.

=item c

Sort by ctime (change time) in seconds since the epoch.

=item f

Equivalent to passing C<all> and setting C<sort> to C<none>.

=item group-directories-first

Return directories then files. The C<sort> algorithm will be applied within
these groupings, but C<U> or C<< sort => 'none' >> will disable the grouping.

=item hide

Omit files and directories matching given L<Text::Glob> pattern. Overriden by
C<a>/C<all> or C<A>/C<almost-all>.

=item I

=item ignore

Omit files and directories matching given L<Text::Glob> pattern.

=item r

=item reverse

Reverse sort order (unless C<U> or C<< sort => 'none' >> specified).

=item sort

Specify sort algorithm other than the default sort-by-name. Valid values are:
C<none>, C<extension>, C<size>, C<time>, or C<version>.

=item S

Sort by file size in bytes (descending). Equivalent to C<< sort => 'size' >>.

=item t

Sort by mtime (modification time) in seconds since the epoch. Equivalent to
C<< sort => 'time' >>.

=item u

Sort by atime (access time) in seconds since the epoch.

=item U

Return entries in directory order (unsorted). Equivalent to
C<< sort => 'none' >>.

=item v

Sort naturally by version numbers within the name. Uses L<Sort::filevercmp>
for sorting. Equivalent to C<< sort => 'version' >>.

=item X

Sort by (last) file extension, according to the current locale. Equivalent to
C<< sort => 'extension' >>.

=back

=head1 CAVEATS

This is only an approximation of L<ls(1)>. It makes an attempt to give the same
output under the supported options, but there may be differences in edge cases.
Weird things might happen with sorting of non-ASCII filenames, or on
non-Unixlike systems. Lots of options aren't supported yet. Patches welcome.

=head1 BUGS

Report any issues on the public bugtracker.

=head1 AUTHOR

Dan Book <dbook@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Dan Book.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=head1 SEE ALSO

L<Path::Tiny>, L<ls(1)>
