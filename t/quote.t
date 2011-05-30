use strict;
use warnings;
use Test::More;

use Net::Emacsclient::Util (
    quote_argument   => { -as => 'quote' },
    unquote_argument => { -as => 'unquote' },
);

use Test::TableDriven (
    quote => {
        foo       => 'foo',
        '-foo'    => '&-foo',
        'f-oo'    => 'f-oo',
        'foo bar' => 'foo&_bar',
        '&'       => '&&',
        '&&'      => '&&&&',
        '&_'      => '&&_',
        '& '      => '&&&_',
        ' &'      => '&_&&',
        "-\n-"    => '&-&n-',
    },
    unquote => {
        foo        => 'foo',
        '&-foo&-'  => '-foo&-',
        '&-&n-'    => "-\n-",
        'foo&_bar' => 'foo bar',
        '&&&&'     => '&&',
        '&_&&'     => ' &',
        '&&&_'     => '& ',
        '&&_'      => '&_',
        'a&&_a'    => 'a&_a',
    },
);

runtests;
