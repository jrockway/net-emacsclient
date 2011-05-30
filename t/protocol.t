use strict;
use warnings;
use Test::More;

use Net::Emacsclient::Protocol;

my (@read, $write) = @_;

my $e = Net::Emacsclient::Protocol->new(
    write_cb => sub { $write = shift },
    read_cb  => sub { push @read, [@_] },
);

$e->emit( eval => '(message "OH HAI")' );

is $write, '-eval (message&_"OH&_HAI")',
    'emit works';

$write = '';

$e->read( '-print foo&_bar&_baz' );
ok !@read, 'nothing read yet';

$e->read; # <sound of toilet flushing>
is_deeply shift @read, [ 'print', 'foo bar baz' ],
    'basic parsing works';

ok !$e->rbuf, 'nothing in the rbuf';

$e->read( '-print test again -flush' );
is_deeply shift @read, [ 'print', 'test', 'again' ],
    'flushed when next command is seen';

is $e->rbuf, '-flush', 'rbuf contains remnants';
$e->read('me');
is $e->rbuf, '-flushme', 'and now it contains everything';

$e->read(' -print foo&_bar&_baz oh&_hai -also some&_crap' );
$e->read;

is_deeply shift @read, ['flushme'], 'got flushme';
is_deeply shift @read, ['print', 'foo bar baz', 'oh hai'], 'got next print';
is_deeply shift @read, ['also', 'some crap'], 'also got some crap';
ok !@read, 'nothing more read';

my $auth = Net::Emacsclient::Protocol->new(
    key     => 'foo bar',
    read_cb => sub {},
);

$auth->emit( eval => '(message "OH HAI")' );
undef $write;
$auth->write_cb( sub { $write = shift } );
is $write, '-auth foo&_bar -eval (message&_"OH&_HAI")',
    'deferred write and emit with a key works';

done_testing;
