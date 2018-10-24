use strict;
use warnings;
use if !$ENV{HOME}, 'Test::More', skip_all => 'No home directory found for current user';

use Dir::ls;
use Cwd 'abs_path';
use File::Spec;
use Test::More;

is abs_path(Dir::ls::_expand_tilde('~')), abs_path($ENV{HOME}), '~ expands to home dir';

my $username = getlogin || getpwuid $>;
SKIP: {
  skip 'username not found', 1 unless defined $username;
  is abs_path(Dir::ls::_expand_tilde("~$username")), abs_path($ENV{HOME}), '~username expands to home dir';
}

my @test_filenames = (qw(foo.bar .. ? a* [abc] foo\bar foo/bar), '{foo,bar}', 'foo bar');
SKIP: {
  skip '~ expands differently from $HOME', scalar(@test_filenames)
    if Dir::ls::_expand_tilde('~') ne $ENV{HOME};
  is Dir::ls::_expand_tilde(File::Spec->catfile('~', $_)), File::Spec->catfile($ENV{HOME}, $_),
    "file '$_' in ~ expands" for @test_filenames;
}

done_testing;
