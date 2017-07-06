use strict;
use warnings;
use Dir::ls;
use Path::Tiny 'tempdir';
use Test::More;

local $ENV{LC_COLLATE} = 'en_US.utf8';

my $testdir = tempdir;

my @testfiles = qw(test1  test2.foo.tar  TEST3  test3.bar  test4.TXT  test5  .test5.log  Test_6.Txt  test7.out  test8.jpg);
my %testcontents = (
  test1 => 'ab',
  TEST3 => 'abcde',
  'test3.bar' => 'abcd',
  test5 => 'abcd',
);
$testdir->child($_)->touch for @testfiles;
$testdir->child($_)->spew($testcontents{$_}) for grep { exists $testcontents{$_} } @testfiles;
$testdir->child('test.d')->mkpath;

my @default_list = ls $testdir;
is_deeply \@default_list,
  [qw(test1  test2.foo.tar  TEST3  test3.bar  test4.TXT  test5  Test_6.Txt  test7.out  test8.jpg  test.d)],
  'default list correct';

my @reverse_list = ls $testdir, {reverse => 1};
is_deeply \@reverse_list,
  [qw(test.d  test8.jpg  test7.out  Test_6.Txt  test5  test4.TXT  test3.bar  TEST3  test2.foo.tar  test1)],
  'reverse list correct';

my @almost_all_list = ls $testdir, {'almost-all' => 1};
is_deeply \@almost_all_list,
  [qw(test1  test2.foo.tar  TEST3  test3.bar  test4.TXT  test5  .test5.log  Test_6.Txt  test7.out  test8.jpg  test.d)],
  'almost-all list correct';

my @all_list = ls $testdir, {all => 1};
is_deeply \@all_list,
  [qw(.  ..  test1  test2.foo.tar  TEST3  test3.bar  test4.TXT  test5  .test5.log  Test_6.Txt  test7.out  test8.jpg  test.d)],
  'all list correct';

my @by_ext_list = ls $testdir, {'almost-all' => 1, sort => 'extension'};
is_deeply \@by_ext_list,
  [qw(test1  TEST3  test5  test3.bar  test.d  test8.jpg  .test5.log  test7.out  test2.foo.tar  Test_6.Txt  test4.TXT)],
  'extension sorted list correct';

my @by_size_list = ls $testdir, {'almost-all' => 1, sort => 'size'};
is_deeply \@by_size_list,
  [qw(test.d  TEST3  test3.bar  test5  test1  test2.foo.tar  test4.TXT  .test5.log  Test_6.Txt  test7.out  test8.jpg)],
  'size sorted list correct';

my @by_version_list = ls $testdir, {'almost-all' => 1, sort => 'version'};
is_deeply \@by_version_list,
  [qw(.test5.log  TEST3  Test_6.Txt  test.d  test1  test2.foo.tar  test3.bar  test4.TXT  test5  test7.out  test8.jpg)],
  'version sorted list correct';

done_testing;
