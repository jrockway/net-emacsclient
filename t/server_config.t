use strict;
use warnings;
use Test::More;

use Test::Fatal;
use Path::Class;
use Net::Emacsclient::Util;


{
    my $self = file(__FILE__)->absolute;
    is( exception { Net::Emacsclient::Util::get_server_config_path($self) }, undef,
        'ok to use absolute file as server config' );
}

if($ENV{HOME} || $ENV{APPDATA} && (-d $ENV{HOME} || -d $ENV{APPDATA})) {
    like(
        exception { Net::Emacsclient::Util::find_tcp_socket('gorch') },
        qr/server file "(.+)gorch" does not exist/,
        'got sane tcp error message',
    );

    like(
        exception { Net::Emacsclient::Util::find_local_socket('gorch') },
        qr{socket "(.+)gorch" does not exist},
        'got sane unix error message',
    );
}
else {
    diag "no homedir?  skipping tests.";
}

my $file = <<HERE;
127.0.0.1:1234 1356
sdkjh239487askdjfhblkjHO[*&^O@#UIHLkj!!>>>
HERE

is_deeply Net::Emacsclient::Util::parse_server_config($file), {
    host => '127.0.0.1',
    port => 1234,
    pid  => 1356,
    key  => 'sdkjh239487askdjfhblkjHO[*&^O@#UIHLkj!!>>>',
}, 'parsed config file ok';

done_testing;
