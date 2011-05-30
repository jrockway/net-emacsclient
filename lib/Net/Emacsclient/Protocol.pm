package Net::Emacsclient::Protocol;
# ABSTRACT: emit and parse emacs messages
use Moose;

use Net::Emacsclient::Util qw/quote_argument unquote_argument/,
    before => { -as => 'elements_before' };

sub unquote_command {
    my ($cmd) = @_;
    $cmd =~ /^-(.+)$/ and return $1;
    return $cmd;
}

use namespace::autoclean -also => ['unquote_command'];

has 'key' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_key',
);

has 'rbuf' => (
    accessor => 'rbuf',
    isa      => 'Str',
    traits   => ['String'],
    default  => sub { '' },
    clearer  => 'clear_rbuf',
    handles  => { append_rbuf => 'append' },
);

has 'wbuf' => (
    reader  => 'wbuf',
    isa     => 'Str',
    traits  => ['String'],
    default => sub { '' },
    clearer => 'clear_wbuf',
    handles => { append_wbuf => 'append' },
);

has 'read_cb' => (
    is       => 'ro',
    isa      => 'CodeRef',
    traits   => ['Code'],
    handles  => { invoke_read_cb => 'execute' },
    required => 1,
);

has 'write_cb' => (
    is        => 'rw',
    predicate => 'has_write_cb',
    isa       => 'CodeRef',
    traits    => ['Code'],
    handles   => { invoke_write_cb => 'execute' },
    trigger   => sub {
        my ($self, $new, $old) = @_;
        if($new && $self->wbuf ne ''){
            $new->($self->wbuf);
            $self->clear_wbuf;
        }
    },
);

sub _auth {
    my $self = shift;
    return '' unless $self->has_key;
    return join ' ', '-auth', quote_argument($self->key);
}

sub _emit {
    my ($self, $command, @args) = @_;
    my $auth = $self->_auth;
    $auth .= ' ' if $auth;
    return join '', $auth, join ' ', "-$command", map { quote_argument($_) } @args;
}

sub write {
    my ($self, $buf) = @_;
    if($self->has_write_cb){
        $self->invoke_write_cb($buf);
    }
    else {
        $self->append_wbuf($buf);
    }
}

sub emit {
    my $self = shift;
    $self->write( $self->_emit(@_) );
}

sub read {
    my ($self, $str) = @_;
    if(defined $str){
        $self->append_rbuf($str);
        $self->parse;
    }
    # invoking with no args flushes rbuf
    elsif($self->rbuf) {
        $self->unquote_and_invoke( split /\s+/, $self->rbuf );
        $self->clear_rbuf;
    }
}

sub unquote_and_invoke {
    my ($self, $command, @args) = @_;
    $self->invoke_read_cb(
        unquote_command($command),
        map { unquote_argument($_) } @args,
    );
}

sub parse {
    my ($self) = @_;

    my $str = $self->rbuf;
    return unless $str;
    $self->clear_rbuf;

    my @elements = split /\s+/, $str;
    my $command = shift @elements;
    my @args = elements_before { /^-/ } @elements;

    if(@args == @elements){
        # not enough information to determine if we've seen all args yet
        $self->rbuf($str);
        return;
    }

    $self->unquote_and_invoke( $command, @args );
    shift @elements for @args;

    if(@elements){
        $self->rbuf(join ' ', @elements);
        goto &parse;
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;
