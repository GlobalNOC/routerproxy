package RouterProxyConfig;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use XML::Simple;

sub New {
    my $class = shift;
    my $path  = shift;
    my $self  = {};

    # Bless the self hash and class
    bless $self, $class;

    $self->{'command_group'} = {'brocade-commands'  => [],
                                'ciena-commands'    => [],
                                'force10-commands'  => [],
                                'hdxc-commands'     => [],
                                'hp-commands'       => [],
                                'ios-commands'      => [],
                                'ios2-commands'     => [],
                                'ios6509-commands'  => [],
                                'iosxr-commands'    => [],
                                'junos-commands'    => [],
                                'ome-commands'      => [],
                                'ons15454-commands' => []};
    $self->{'device'}        = {};
    $self->{'device_group'}  = {};
    $self->{'frontend'}      = {};
    $self->{'logging'}       = "";
    $self->{'maximum'}       = {};

    if (index($path, ".xml") != -1 || index($path, ".conf") != -1) {
        $self->loadXML($path);
    } else {
        $self->loadJSON($path);
    }

    return $self;
}

=head2 loadXML

Loads configuration from a deprecated XML file.

=cut
sub loadXML {
    my $self = shift;
    my $path = shift;

    my $xml = XMLin($path, forcearray => 1);

    $self->{'frontend'}->{'dropdown'}     = $xml->{'enable-menu-commands'}->[0];
    $self->{'frontend'}->{'network_name'} = $xml->{'network'}->[0];
    $self->{'frontend'}->{'noc_name'}     = $xml->{'noc'}->[0];
    $self->{'frontend'}->{'noc_site'}     = $xml->{'noc-website'}->[0];
    $self->{'frontend'}->{'noc_mail'}     = $xml->{'email'}->[0];
    $self->{'frontend'}->{'help'}         = $xml->{'command-help'}->[0];
    
    $self->{'logging'}                    = $xml->{'log-file'}->[0];

    $self->{'maximum'}->{'lines'}         = $xml->{'max-lines'}->[0];
    $self->{'maximum'}->{'timeout'}       = $xml->{'timeout'}->[0];
    $self->{'maximum'}->{'rate'}          = $xml->{'spam-seconds'}->[0];

    # Create device groups for layer1, layer2, and layer3 devices.
    my $l1_group = { name        => $xml->{'layer1-title'}->[0],
                     display     => $xml->{'layer1-collapse'}->[0],
                     description => $xml->{'layer1-title'}->[0],
                     devices     => [] };
    $self->{'device_group'}->{$l1_group->{'name'}} = $l1_group;
    
    my $l2_group = { name        => $xml->{'layer2-title'}->[0],
                     display     => $xml->{'layer2-collapse'}->[0],
                     description => $xml->{'layer2-title'}->[0],
                     devices     => [] };
    $self->{'device_group'}->{$l2_group->{'name'}} = $l2_group;

    my $l3_group = { name        => $xml->{'layer3-title'}->[0],
                     display     => $xml->{'layer3-collapse'}->[0],
                     description => $xml->{'layer3-title'}->[0],
                     devices     => [] };
    $self->{'device_group'}->{$l3_group->{'name'}} = $l3_group;


    foreach my $device (@{$xml->{'device'}}) {
        my $_device = {};
        $_device->{'name'}     = $device->{'name'}->[0];
        $_device->{'username'} = $device->{'username'}->[0];
        $_device->{'state'}    = $device->{'state'}->[0];
        $_device->{'city'}     = $device->{'city'}->[0];
        $_device->{'group'}    = $device->{'layer'}->[0];
        $_device->{'password'} = $device->{'password'}->[0];
        $_device->{'address'}  = $device->{'address'}->[0];
        $_device->{'method'}   = $device->{'method'}->[0];
        $_device->{'type'}     = $device->{'type'}->[0]; # change to dev type

        # Add configured command group.
        my $_command_group = $_device->{'type'} . '-commands';
        $_device->{'command_group'} = [ $_command_group ];
        
        # Add configured device to the device hash.
        $self->{'device'}->{ $_device->{'name'} } = $_device;

        # Add configured device to the proper device group.
        if ($_device->{'group'} == 1) {
            push(@{$self->{'device_group'}->{$l1_group->{'name'}}->{'devices'}}, $_device);
        } elsif ($_device->{'group'} == 2) {
            push(@{$self->{'device_group'}->{$l2_group->{'name'}}->{'devices'}}, $_device);
        } elsif ($_device->{'group'} == 3) {
            push(@{$self->{'device_group'}->{$l3_group->{'name'}}->{'devices'}}, $_device);
        } else {
            warn "Device $_device->{'name'} was not added to a device group.";
        }
    }

    foreach my $cmd_type (keys %{$self->{'command_group'}}) {
        foreach my $cmd (@{$xml->{$cmd_type}->[0]->{'command'}}) {
            push(@{$self->{'command_group'}->{$cmd_type}}, $cmd);
        }
    }
    
    return 1;
}

=head2 loadJSON

Loads configuration from a JSON file.

=cut
sub loadJSON {
    my $self = shift;
    my $path = shift;
}

sub Device {
    my $self = shift;
    my $name = shift;

    return $self->{'device'}->{$name};
}

=head2 Devices

Returns a copy of the devices in this config as a hash.

=cut
sub Devices {
    my $self = shift;
    return \%{$self->{'device'}};
}

=head2 DeviceGroups

Returns a copy of the device groups in this config as a hash.

=cut
sub DeviceGroups {
    my $self = shift;
    return \%{$self->{'device_group'}};
}

=head2 DeviceCommands

Returns the allowed commands for the device named $name.

=cut
sub DeviceCommands {
    my $self = shift;
    my $name = shift;

    my $result = [];
    my $groups = $self->{'device'}->{$name}->{'command_group'};

    foreach my $group (@{$groups}) {
        foreach my $command (@{$self->{'command_group'}->{$group}}) {
            push(@{$result}, $command);
        }
    }
    return $result;
}

=head2 GroupDevices

Returns the devices in the group named $group.

=cut
sub GroupDevices {
    my $group = shift;
}

=head2 LogFile

Returns the path where logs should be written.

=cut
sub LogFile {
    my $self = shift;
    return $self->{'logging'};
}

=head2 MaxLines

Returns the maximum number of lines allowed in a switch response.

=cut
sub MaxLines {
    my $self = shift;
    return $self->{'maximum'}->{'lines'};
}

=head2 MaxRate

Returns the maximum rate in seconds that requests may be made.

=cut
sub MaxRate {
    my $self = shift;
    return $self->{'maximum'}->{'rate'};
}

=head2 MaxTimeout

Returns the maximum number of seconds to wait before timing out.

=cut
sub MaxTimeout {
    my $self = shift;
    return $self->{'maximum'}->{'timeout'};
}

sub NetworkName {
    my $self = shift;
    return $self->{'frontend'}->{'network_name'};
}

sub NOCName {
    my $self = shift;
    return $self->{'frontend'}->{'noc_name'};
}

sub NOCMail {
    my $self = shift;
    return $self->{'frontend'}->{'noc_mail'};
}

sub NOCSite {
    my $self = shift;
    return $self->{'frontend'}->{'noc_site'};
}

sub NOCHelp {
    my $self = shift;
    return $self->{'frontend'}->{'help'};
}

sub ShowDropdown {
    my $self = shift;
    return $self->{'frontend'}->{'dropdown'};
}

return 1;
