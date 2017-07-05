package Dir::ls;

use strict;
use warnings;
use Carp 'croak';
use Exporter 'import';

our $VERSION = '0.001';

our @EXPORT = 'ls';

sub ls {
  my ($dir, $options) = @_;
  $options ||= {};
  opendir my $dh, $dir or croak "Failed to open directory '$dir': $!";
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
    # pre-sort by name
    my @names = map { lc _name($_) } @entries;
    @entries = @entries[sort { $names[$a] cmp $names[$b] or $entries[$a] cmp $entries[$b] } 0..$#entries];
    
    if ($options->{S} or $options->{sort} eq 'size') {
      my @sizes = map { _stat($dir, $_, 7) } @entries;
      @entries = @entries[sort { $sizes[$a] <=> $sizes[$b] } 0..$#entries];
    } elsif ($options->{t} or $options->{sort} eq 'time') {
      my @mtimes = map { _stat($dir, $_, 9) } @entries;
      @entries = @entries[sort { $mtimes[$a] <=> $mtimes[$b] } 0..$#entries];
    } elsif ($options->{v} or $options->{sort} eq 'version') {
      # TODO: sort as in filevercmp
    } elsif ($options->{X} or $options->{sort} eq 'extension') {
      my @extensions = map { lc _ext($_) } @entries;
      @entries = @entries[sort { $extensions[$a] cmp $extensions[$b] } 0..$#entries];
    } elsif ($options->{c}) {
      my @ctimes = map { _stat($dir, $_, 10) } @entries;
      @entries = @entries[sort { $ctimes[$a] <=> $ctimes[$b] } 0..$#entries];
    } elsif ($options->{u}) {
      my @atimes = map { _stat($dir, $_, 8) } @entries;
      @entries = @entries[sort { $atimes[$a] <=> $atimes[$b] } 0..$#entries];
    } elsif (length $options->{sort}) {
      croak "Unknown sort option '$options->{sort}'; must be 'none', 'size', 'time', 'version', or 'extension'";
    }
  }
  
  return @entries;
}

sub _stat {
  my ($dir, $entry, $index) = @_;
  my @stat = stat "$dir/$entry";
  croak "Failed to stat '$dir/$entry': $!" unless @stat;
  return $stat[$index];
}

sub _ext {
  my ($entry) = @_;
  my ($ext) = $entry =~ m/(\.[^.]*)$/;
  $ext = '' unless defined $ext;
  return $ext;
}

sub _name {
  my ($entry) = @_;
  # Only consider alphabetic, numeric, and blank characters (space + tab)
  $entry =~ tr/a-zA-Z0-9 \t//cd;
  return $entry;
}

1;

=head1 NAME

Dir::ls - List the contents of a directory

=head1 SYNOPSIS

  use Dir::ls;
  
  print "$_\n" for ls '.';
  
  print "$_\n" for ls '/foo/bar', {all => 1, sort => 'time'};

=head1 DESCRIPTION

=head1 FUNCTIONS

=head2 ls

  my @contents = ls $dir, \%options;

=head1 BUGS

Report any issues on the public bugtracker.

=head1 AUTHOR

Dan Book <dbook@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Dan Book.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=head1 SEE ALSO

L<Path::Tiny>
