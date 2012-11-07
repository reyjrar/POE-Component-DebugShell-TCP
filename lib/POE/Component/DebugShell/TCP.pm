# ABSTRACT: DebugShell accessible via a TCP Port
package POE::Component::DebugShell::TCP;

use strict;
use warnings;

use POE qw(
    API::Peek
    Component::Server::TCP
);

our $VERSION = 0.01;

=head1 SYNOPSIS

This POE Component provides a debugging port for your application to
see the internal using the capabilities provided by POE::API::Peek.

    use POE qw(
        Component::DebugShell::TCP
    );

    # Message Dispatch Service
    my $SESSION = POE::Component::DebugShell::TCP->spawn(
            ListenAddress       => 'localhost',         #default
            ListenPort          => 9094,              #default
    );

    POE::Kernel->run();

=head1 EXPORT

POE::Component::Server::eris does not export any symbols.

=cut


=head1 FUNCTIONS

=head2 spawn

Creates the POE::Session for the DebugShell.

Parameters:
    ListenAddress           => 'localhost',         #default
    ListenPort              => '9094',              #default

=cut

sub spawn {
    my $type = shift;

    #
    # Param Setup
    my %args = (
        ListenAddress   => 'localhost',
        ListenPort      => 9094,
        @_
    );

    # TCP Session Master
    my $tcp_sess_id = POE::Component::Server::TCP->new(
            Alias       => 'debug_shell',
            Address     => $args{ListenAddress},
            Port        => $args{ListenPort},

            Error               => \&server_error,
            ClientConnected     => \&client_connect,
            ClientInput         => \&client_input,

            ClientDisconnected  => \&client_term,
            ClientError         => \&client_term,
    );

    return $tcp_sess_id;
}

=head2 INTERNAL FUNCTIONS

=head3 client_connect

Handles connection establishment

=cut

sub client_connect {
    my ($kernel,$heap,$ses) = @_[KERNEL,HEAP,SESSION];

    my $KID = $kernel->ID();
    my $CID = $heap->{client}->ID;
    my $SID = $ses->ID;

    $heap->{clients}{ $SID } = $heap->{client};
    $heap->{client}->put("Dispatcher API Peek: (kernel:$KID, client:$CID, server:$SID)");
}

=head3 client_input

Handles client input

=cut

sub client_input {
    my ($kernel,$heap,$ses,$msg) = @_[KERNEL,HEAP,SESSION,ARG0];

    return unless $msg eq 'status';

    my $api = POE::API::Peek->new();
    my @stats = ();
    push @stats, "ksize:" . $api->kernel_memory_size;
    my $list = $api->event_list;
    foreach my $sid (sort { $a <=> $b } keys %{ $list} ) {
        next if $sid eq $ses->ID;
        my $total = $api->event_count_to($sid) + $api->event_count_from($sid);
        my $ses_size = $api->session_memory_size($sid);
        my @aliases = $api->session_alias_list($sid);
        my $name = @aliases > 0 ? join('|', @aliases) : $sid;
        my @reducers = qw(k m g);
        my $unit = 'b';
        my $refs = $api->get_session_refcount($sid);
        while ( $ses_size > 1024 && @reducers ) {
            $ses_size /= 1024;
            $unit = shift @reducers;
        }
        my $sz = sprintf( '%0.2f%s', $ses_size, $unit);
        push @stats, "s:$name(R=$refs,sz=$sz)";
    }

    $heap->{clients}{$ses->ID}->put( join(", ", @stats) );
}

=head3 client_term

Handles client termination

=cut

sub client_term {
    my ($kernel,$heap,$ses) = @_[KERNEL,HEAP,SESSION];
    my $sid = $ses->ID;

    delete $heap->{clients}{$sid};
}

=head1 SEE ALSO

=over

=item L<POE::API::Peek|http://search.cpan.org/dist/POE-API-Peek>

=item L<POE::Component::DebugShell|http://search.cpan.org/dist/POE-Component-DebugShell>

=item L<POE::Component::DebugShell::Jabber|http://search.cpan.org/dist/POE-Component-DebugShell-Jabber>

=back

=cut

# Return True;
1;

