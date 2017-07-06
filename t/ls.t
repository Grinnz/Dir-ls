use strict;
use warnings;
use Dir::ls;
use Path::Tiny 'path';
use Test::More;

my $testdir = path(__FILE__)->absolute->sibling('testdir');

my @default_list = ls $testdir;
is_deeply \@default_list,
  [qw(test1  test2.foo.tar  TEST3  test3.bar  test4.TXT  test5  Test_6.Txt  test7.out  test8.jpg  test.d)],
  'default list correct';

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

done_testing;