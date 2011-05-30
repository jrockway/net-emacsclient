use strict;
use warnings;
use Test::More;

use JSON;
use AnyEvent;

use Net::Emacsclient::Util qw(find_socket);
use AnyEvent::Emacsclient qw(emacsclient);

my $json = JSON->new->pretty(0);

my $socket = eval { find_socket() };

plan 'skip_all' => 'cannot connect to emacs'
    unless $socket;

ok $socket, 'found emacs socket: '. $json->encode($socket);

my $cv = AnyEvent->condvar;
my $h = emacsclient(
    [ eval => '(+ 2 2)' ],
    { warn_on_error => 1 },
    sub { $cv->send([@_]) },
);

my $result = $cv->recv;
is_deeply $result, ['print', '4'], 'got result from emacs';

done_testing;
