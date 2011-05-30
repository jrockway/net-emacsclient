package Net::Emacsclient::Util;
# ABSTRACT: random crap that doesn't belong elsewhere
use strict;
use warnings;
use feature 'switch';

use Carp qw(confess);
use Path::Class;
use Try::Tiny;

# we import and re-export this because "before" conflicts with Moose
# and S::E will allow us to rename it upon import.
use List::MoreUtils qw(before);

use Sub::Exporter -setup => {
    exports => [qw/quote_argument unquote_argument find_socket before/],
};

sub quote_argument($) {
    my ($str) = @_;
    $str =~ s/&/&&/g;
    $str =~ s/ /&_/g;
    $str =~ s/\n/&n/g;
    $str =~ s/^-/&-/;
    return $str;
}

sub unquote_argument($) {
    my ($str) = @_;
    my $out = '';

    if ($str =~ /^&-(.*)$/) {
        $out = '-';
        $str = $1;
    }

    while($str =~ /^([^&]*)&([&_n])(.*)$/g){
        $out .= "$1";
        given($2){
            when(/_/){
                $out .= ' ';
            }
            when(/n/){
                $out .= "\n";
            }
            default {
                $out .= $2;
            }
        }
        $str = $3;
    }

    return "$out$str";
}

sub get_server_config_path {
    my $server_file = shift;
    $server_file ||= 'server';

    $server_file = file($server_file || 'server')->cleanup;

    # if it's absolute, just pass it through
    if ($server_file->is_absolute){
        confess qq{server file "$server_file" is absolute, but does not exist}
            unless -e $server_file;

        return $server_file->resolve;
    }

    # if it's not absolute, then we assume it's the filename under
    # ~/.emacs.d/server/.  (note that ~ is Emacs' idea of ~, not
    # perl's idea of ~.)
    my $home = $^O eq 'MSWin32' ? ($ENV{APPDATA} || $ENV{HOME}) : $ENV{HOME};

    confess q{no homedir in $ENV{HOME} or $ENV{APPDATA}}
        unless $home;

    confess qq{homedir "$home" does not exist}
        unless -d $home;

    $home = dir($home);
    $server_file = $home->subdir('.emacs.d')->subdir('server')->file($server_file);
    $server_file = $server_file->cleanup;

    confess qq{server file "$server_file" does not exist}
        unless -e $server_file;

    return $server_file->resolve;
}

sub parse_server_config {
    my $str = shift;
    my ($info, $key) = split /\n/, $str;
    chomp($info, $key);

    my ($host_port, $pid) = split / /, $info;
    my ($host, $port) = split /:/, $host_port;

    return {
        host => $host,
        port => $port,
        pid  => $pid,
        key  => $key,
    }
}

sub find_tcp_socket {
    my $server_file = get_server_config_path($_[0]);
    return parse_server_config($server_file->slurp);
}

sub find_local_socket {
    my $server_name = shift || 'server';

    # XXX: this may be broken on darwin; emacsclient.c talks about
    # _CS_DARWIN_USER_TEMP_DIR which i don't understand well enough to
    # implement.  patch welcome.

    my $tmp = $ENV{TMPDIR} || '/tmp';

    my $socket_name = sprintf(
        '%s/emacs%d/%s', $tmp, $>, $server_name,  # /tmp/emacs<effective uid>/server
    );

    confess qq{socket "$socket_name" does not exist}
        unless -e $socket_name;

    confess qq{socket "$socket_name" is not owned by our effective UID ($>)}
        unless -o $socket_name;

    return $socket_name;
}

sub find_socket {
    my %args = @_;

    my ($tcp, $unix, $tcp_error, $unix_error);

    try {
        $unix = find_local_socket($args{server_name});
    }
    catch {
        $unix_error = $_;
        try {
            $tcp = find_tcp_socket($args{server_file});
        }
        catch {
            $tcp_error = $_;
        }
    };

    return { unix => $unix } if $unix && !$unix_error;
    return $tcp if $tcp && !$tcp_error;

    confess qq{no luck finding any way to connect to emacs: }.
        qq{failed finding unix socket with error `$unix_error', }.
        qq{and failed finding tcp socket with error `$tcp_error'.};
}

1;

__END__

=head1 EXPORTS

You can import any of these functions by name.  There are no default
exports.

=head2 quote_argument($)

Quote a literal string in the emacsclient format.  From C<emacsclient.c>:

=over 4

In STR, insert a & before each &, each space, each newline, and
any initial -.  Change spaces to underscores, too, so that the
return value never contains a space.

=back

=head2 unquote_argument($)

Reverse C<quote_argument>.
