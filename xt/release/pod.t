use strict;
use warnings;
use Test::More;
BEGIN { 
  plan skip_all => 'test requires Test::Pod' 
    unless eval q{ use Test::Pod; 1 };
};
use Test::Pod;

all_pod_files_ok( grep { -e $_ } qw( bin lib ));

