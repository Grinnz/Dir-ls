package Dir::ls;

use strict;
use warnings;
use Carp 'croak';
use Exporter 'import';
use Path::Tiny 'path';
use sort 'stable';

our $VERSION = '0.001';

our @EXPORT = 'ls';

sub ls {
  my ($dir, $options) = @_;
  $options ||= {};
  
  $dir = path($dir); # do glob expansion
  
  opendir my $dh, "$dir" or croak "Failed to open directory '$dir': $!";
  my @entries = readdir $dh;
  closedir $dh or croak "Failed to close directory '$dir': $!";
  
  unless ($options->{a} or $options->{all} or $options->{f}) {
    if ($options->{A} or $options->{'almost-all'}) {
      @entries = grep { $_ ne '.' and $_ ne '..' } @entries;
    } else {
      @entries = grep { !m/^\./ } @entries;
    }
  }
  
  local $options->{sort} = '' unless defined $options->{sort};
  unless ($options->{U} or $options->{sort} eq 'none' or $options->{f}) {
    if ($options->{v} or $options->{sort} eq 'version') {
      # Algorithm from filevercmp
      my @vparts = map { _version_sorter($_) } @entries;
      no locale;
      @entries = @entries[sort {
        my ($aspecial, $bspecial) = ($vparts[$a]{special}, $vparts[$b]{special});
        return $aspecial cmp $bspecial if defined $aspecial and defined $bspecial;
        return -1 if defined $aspecial;
        return 1 if defined $bspecial;
        
        my ($ahidden, $bhidden) = ($vparts[$a]{hidden}, $vparts[$b]{hidden});
        return -1 if $ahidden and !$bhidden;
        return 1 if !$ahidden and $bhidden;
        
        my ($aparts, $bparts) = ($vparts[$a]{parts}, $vparts[$b]{parts});
        my $partscmp = _version_partscmp($aparts, $bparts);
        return $partscmp if $partscmp;
        
        my ($asuffix, $bsuffix) = ($vparts[$a]{suffix}, $vparts[$b]{suffix});
        my $suffixcmp = _version_partscmp($asuffix, $bsuffix);
        return $suffixcmp;
      } 0..$#entries];
    } else {
      {
        # pre-sort by alphanumeric then full name
        my @alnum = map { _alnum_sorter($_) } @entries;
        use locale;
        @entries = @entries[sort { $alnum[$a] cmp $alnum[$b] or $entries[$a] cmp $entries[$b] } 0..$#entries];
      }
      
      if ($options->{S} or $options->{sort} eq 'size') {
        my @sizes = map { _stat_sorter($dir, $_, 7) } @entries;
        @entries = @entries[sort { $sizes[$b] <=> $sizes[$a] } 0..$#entries];
      } elsif ($options->{X} or $options->{sort} eq 'extension') {
        my @extensions = map { _ext_sorter($_) } @entries;
        use locale;
        @entries = @entries[sort { $extensions[$a] cmp $extensions[$b] } 0..$#entries];
      } elsif ($options->{t} or $options->{sort} eq 'time') {
        my @mtimes = map { _stat_sorter($dir, $_, 9) } @entries;
        @entries = @entries[sort { $mtimes[$a] <=> $mtimes[$b] } 0..$#entries];
      } elsif ($options->{c}) {
        my @ctimes = map { _stat_sorter($dir, $_, 10) } @entries;
        @entries = @entries[sort { $ctimes[$a] <=> $ctimes[$b] } 0..$#entries];
      } elsif ($options->{u}) {
        my @atimes = map { _stat_sorter($dir, $_, 8) } @entries;
        @entries = @entries[sort { $atimes[$a] <=> $atimes[$b] } 0..$#entries];
      } elsif (length $options->{sort}) {
        croak "Unknown sort option '$options->{sort}'; must be 'none', 'size', 'time', 'version', or 'extension'";
      }
    }
    
    @entries = reverse @entries if $options->{r} or $options->{reverse};
  }
  
  return @entries;
}

sub _stat_sorter {
  my ($dir, $entry, $index) = @_;
  $entry = $dir->child($entry);
  my @stat = stat $entry;
  croak "Failed to stat '$entry': $!" unless @stat;
  return $stat[$index];
}

sub _ext_sorter {
  my ($entry) = @_;
  my ($ext) = $entry =~ m/(\.[^.]*)$/;
  $ext = '' unless defined $ext;
  return $ext;
}

sub _alnum_sorter {
  my ($entry) = @_;
  # Only consider alphabetic, numeric, and blank characters (space + tab)
  $entry =~ tr/a-zA-Z0-9 \t//cd;
  return $entry;
}

sub _version_sorter {
  my ($entry) = @_;
  return { special => $entry } if $entry eq '' or $entry eq '.' or $entry eq '..';
  my $hidden = $entry =~ s/^\.//;
  my $suffix = '';
  if ($entry =~ s/((?:\.[A-Za-z~][A-Za-z0-9~]*)*)$//) {
    $suffix = $1;
  }
  my (@parts, @suffix);
  while ($entry =~ s/^([^0-9]*)([0-9]*)// and (length $1 or length $2)) {
    push @parts, $1, $2;
  }
  while ($suffix =~ s/^([^0-9]*)([0-9]*)// and (length $1 or length $2)) {
    push @suffix, $1, $2;
  }
  return { hidden => $hidden, suffix => \@suffix, parts => \@parts };
}

# tilde sorts first even before end of string, then letters, then everything else
sub _version_lexorder {
  my ($char) = @_;
  return 0 if $char =~ m/\A[0-9]\z/;
  return ord $char if $char =~ m/\A[a-zA-Z]\z/;
  return -1 if $char eq '~';
  return ord($char) + ord('z') + 1;
}

sub _version_lexcmp {
  my ($alex, $blex) = @_;
  my @achars = split '', $alex;
  my @bchars = split '', $blex;
  while (@achars or @bchars) {
    my ($achar, $bchar) = (shift(@achars), shift(@bchars));
    my $aord = defined $achar ? _version_lexorder($achar) : 0;
    my $bord = defined $bchar ? _version_lexorder($bchar) : 0;
    my $charcmp = $aord <=> $bord;
    return $charcmp if $charcmp;
  }
  return 0;
}

sub _version_partscmp {
  my @aparts = @{$_[0] || []};
  my @bparts = @{$_[1] || []};
  while (@aparts or @bparts) {
    my ($alex, $blex) = (shift(@aparts), shift(@bparts));
    $alex = '' unless defined $alex;
    $blex = '' unless defined $blex;
    my $lexcmp = _version_lexcmp($alex, $blex);
    return $lexcmp if $lexcmp;
    my ($anum, $bnum) = (shift(@aparts), shift(@bparts));
    $anum = 0 unless defined $anum and length $anum;
    $bnum = 0 unless defined $bnum and length $bnum;
    my $numcmp = $anum <=> $bnum;
    return $numcmp if $numcmp;
  }
  return 0;
}

1;

=head1 NAME

Dir::ls - List the contents of a directory

=head1 SYNOPSIS

  use Dir::ls;
  
  print "$_\n" for ls '.';
  
  print "$_: ", -s "/foo/bar/$_", "\n" for ls '/foo/bar', {all => 1, sort => 'size'};

=head1 DESCRIPTION

Provides the function L</"ls">, which returns the contents of a directory in a
similar manner to the GNU coreutils command L<ls(1)>.

=head1 FUNCTIONS

=head2 ls

  my @contents = ls $dir, \%options;

Takes a directory path and optional hashref of options, and returns a list of
items in the directory. Home directories represented by C<~> will be expanded
by L<Path::Tiny/"path">. Like in L<ls(1)>, the returned names are relative to
the passed directory path, so if you want to use a filename (such as passing it
to C<open> or C<stat>), you must prefix it with the directory path, with C<~>
expanded if present.

  # Check the size of a file in current user's home directory
  my @contents = ls '~';
  say -s glob('~') . "/$contents[0]";

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

=item c

Sort by ctime (change time) in seconds since the epoch.

=item f

Equivalent to passing C<all> and setting C<sort> to C<none>.

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

Sort naturally by version numbers within the name. This sort algorithm ignores
the current locale. Equivalent to C<< sort => 'version' >>.

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
