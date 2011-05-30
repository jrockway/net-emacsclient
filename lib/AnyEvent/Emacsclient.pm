package AnyEvent::Emacsclient;
# ABSTRACT: non-blocking interaction with Emacs
use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

use Sub::Exporter -setup => {
    exports => [qw/emacsclient/],
};

use Net::Emacsclient::Protocol;
use Net::Emacsclient::Util qw(find_socket);

sub emacsclient {
    my (@commands) = @_;
    my $cb = pop @commands;
    my %args = %{pop @commands} if ref $commands[-1] eq 'HASH';

    my $spec = find_socket(%args);

    my @emacs_args = ( read_cb => $cb );
    push @emacs_args, key => $spec->{tcp}{key} if exists $spec->{tcp};
    my $emacs = Net::Emacsclient::Protocol->new( @emacs_args );

    my $host = exists $spec->{tcp} ? $spec->{tcp}{host} : 'unix/';
    my $port = exists $spec->{tcp} ? $spec->{tcp}{port} : $spec->{unix};

    my $h = AnyEvent::Handle->new(
        connect    => [$host, $port],
        on_connect => sub {
            my ($h, $host, $port) = @_;
            $h->on_read( sub {
                my $h = shift;
                $emacs->read( delete $h->{rbuf} );
            });

            $emacs->write_cb( sub {
                $h->push_write("@_\r\n"),
            });

            $emacs->emit(@$_) for @commands;
        },
        on_error => sub {
            my ($h, $fatal, $msg) = @_;
            if($args{warn_on_error}){
                warn "error in emacsclient: $msg";
            }

            if($fatal){
                if($h->{rbuf}){
                    $emacs->read( delete $h->{rbuf} );
                }
                $emacs->read;
                $cb->( [ 'error', $msg, 1 ] );
                $h->destroy;
            }
        },
        on_eof  => sub {
            my $h = shift;
            $h->on_error();
            $h->on_read();
            $emacs->read;
            $h->destroy;
        },
    );

    return $h;
}

1;
