package GRNOC::RouterProxy::Config;

use strict;
use warnings;

use Log::Log4perl;
use XML::Simple;
use YAML;

sub New {
    my $class = shift;
    my $self  = {
        log  => Log::Log4perl->get_logger('GRNOC.RouterProxy.Config'),
        path => shift
    };

    bless $self, $class;

    $self->{'command_group'} = {};
    $self->{'device'}        = {};
    $self->{'device_group'}  = {};
    $self->{'frontend'}      = {};
    $self->{'general'}->{'logging'}       = "";
    $self->{'maximum'}       = {};

    if (index($self->{'path'}, ".xml") != -1 || index($self->{'path'}, ".conf") != -1) {
        $self->loadXML($self->{'path'});
    } else {
        $self->loadYAML();
    }

    return $self;
}

=head2 loadXML

Loads configuration from a deprecated XML file.

=cut
sub loadXML {
    my $self = shift;
    my $path = shift;

    $self->{'log'}->info("Loading xml configuration from $self->{'path'}.");

    my $xml = XMLin($path, forcearray => 1);

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

    $self->{'frontend'}->{'dropdown'}     = $xml->{'enable-menu-commands'}->[0] || 0;
    $self->{'frontend'}->{'network_name'} = $xml->{'network'}->[0];
    $self->{'frontend'}->{'noc_name'}     = $xml->{'noc'}->[0];
    $self->{'frontend'}->{'noc_site'}     = $xml->{'noc-website'}->[0];
    $self->{'frontend'}->{'noc_mail'}     = $xml->{'email'}->[0];
    $self->{'frontend'}->{'help'}         = $xml->{'command-help'}->[0] || '';

    $self->{'general'}->{'logging'}       = $xml->{'log-file'}->[0];

    $self->{'general'}->{'max_lines'}     = $xml->{'max-lines'}->[0];
    $self->{'general'}->{'max_timeout'}   = $xml->{'timeout'}->[0];
    $self->{'general'}->{'max_rate'}      = $xml->{'spam-seconds'}->[0];

    $self->{'general'}->{'redact'}                     = [];
    if (defined $xml->{'redact-stanzas'} && defined $xml->{'redact-stanzas'}->[0]) {
        foreach my $s (@{$xml->{'redact-stanzas'}->[0]->{'stanza'}}) {
            push(@{$self->{'general'}->{'redact'}}, $s);
        }
    }

    # Create device groups for layer1, layer2, and layer3 devices.
    my $l1_group = { name        => $xml->{'layer1-title'}->[0],
                     display     => $xml->{'layer1-collapse'}->[0],
                     description => $xml->{'layer1-title'}->[0],
                     devices     => [] };
    if (defined $l1_group->{'display'} && $l1_group->{'display'} == 1) {
        $l1_group->{'display'} = 0; # Negate boolean. If collapse no display.
    } else {
        $l1_group->{'display'} = 1;
    }
    $self->{'device_group'}->{$xml->{'layer1-title'}->[0]} = $l1_group;
    $self->{'device_group'}->{$xml->{'layer1-title'}->[0]}->{'position'} = 2;

    my $l2_group = { name        => $xml->{'layer2-title'}->[0],
                     display     => $xml->{'layer2-collapse'}->[0],
                     description => $xml->{'layer2-title'}->[0],
                     devices     => [] };
    if (defined $l2_group->{'display'} && $l2_group->{'display'} == 1) {
        $l2_group->{'display'} = 0; # Negate boolean. If collapse no display.
    } else {
        $l2_group->{'display'} = 1;
    }
    $self->{'device_group'}->{$xml->{'layer2-title'}->[0]} = $l2_group;
    $self->{'device_group'}->{$xml->{'layer2-title'}->[0]}->{'position'} = 1;

    my $l3_group = { name        => $xml->{'layer3-title'}->[0],
                     display     => $xml->{'layer3-collapse'}->[0],
                     description => $xml->{'layer3-title'}->[0],
                     devices     => [] };
    if (defined $l3_group->{'display'} && $l3_group->{'display'} == 1) {
        $l3_group->{'display'} = 0; # Negate boolean. If collapse no display.
    } else {
        $l3_group->{'display'} = 1;
    }
    $self->{'device_group'}->{$xml->{'layer3-title'}->[0]} = $l3_group;
    $self->{'device_group'}->{$xml->{'layer3-title'}->[0]}->{'position'} = 0;

    my $position = 0;
    foreach my $device (@{$xml->{'device'}}) {
        my $_device = {};
        $_device->{'name'}     = $device->{'name'}->[0];
        $_device->{'username'} = $device->{'username'}->[0];
        $_device->{'state'}    = $device->{'state'}->[0];
        $_device->{'city'}     = $device->{'city'}->[0];
        $_device->{'device_group'} = $device->{'layer'}->[0];
        $_device->{'password'} = $device->{'password'}->[0];
        $_device->{'address'}  = $device->{'address'}->[0];
        $_device->{'method'}   = $device->{'method'}->[0];
        $_device->{'type'}     = $device->{'type'}->[0]; # change to dev type
        $_device->{'position'} = $position;
        $position = $position + 1;
        
        # Add configured command group.
        my $_command_group = $_device->{'type'} . '-commands';
        $_device->{'command_group'} = [ $_command_group ];
        $_device->{'exclude_group'} = [ 'ex-' . $_command_group ];
        
        # Add configured device to the device hash.
        $self->{'device'}->{ $_device->{'address'} } = $_device;

        # Add configured device to the proper device group.
        if ($_device->{'device_group'} == 1) {
            $_device->{'device_group'} = $xml->{'layer1-title'}->[0];
            push(@{$self->{'device_group'}->{$xml->{'layer1-title'}->[0]}->{'devices'}}, $_device);
        } elsif ($_device->{'device_group'} == 2) {
            $_device->{'device_group'} = $xml->{'layer2-title'}->[0];
            push(@{$self->{'device_group'}->{$xml->{'layer2-title'}->[0]}->{'devices'}}, $_device);
        } elsif ($_device->{'device_group'} == 3) {
            $_device->{'device_group'} = $xml->{'layer3-title'}->[0];
            push(@{$self->{'device_group'}->{$xml->{'layer3-title'}->[0]}->{'devices'}}, $_device);
        } else {
            warn "Device $_device->{'name'} was not added to a device group.";
        }
    }

    foreach my $cmd_type (keys %{$self->{'command_group'}}) {
        foreach my $cmd (@{$xml->{$cmd_type}->[0]->{'command'}}) {
            push(@{$self->{'command_group'}->{$cmd_type}}, $cmd);
        }

        foreach my $cmd (@{$xml->{$cmd_type}->[0]->{'exclude'}}) {
            push(@{$self->{'command_group'}->{'ex-' . $cmd_type}}, $cmd);
        }
    }
    
    return 1;
}

=head2 loadJSON

Loads configuration from a JSON file.

=cut
sub loadYAML {
    my $self = shift;

    $self->{'log'}->info("Loading yaml configuration from $self->{'path'}.");

    my $yaml = YAML::LoadFile($self->{'path'});

    $self->{'frontend'} = $yaml->{'frontend'};
    $self->{'general'}  = $yaml->{'general'};

    $self->{'command_group'} = $yaml->{'command_group'};

    my $position = 0;
    $self->{'device_group'} = {};
    foreach my $group (@{$yaml->{'device_group'}}) {
        $self->{'device_group'}->{$group->{'name'}} = $group;
        $self->{'device_group'}->{$group->{'name'}}->{'devices'} = [];
        $self->{'device_group'}->{$group->{'name'}}->{'position'} = $position;
        $position = $position + 1;
    }

    $position = 0;
    $self->{'device'} = {};
    foreach my $device (@{$yaml->{'device'}}) {
        $self->{'device'}->{$device->{'address'}} = $device;
        $self->{'device'}->{$device->{'address'}}->{'position'} = $position;
        $position = $position + 1;

        # Ensure that a list is defined for exclude commands.
        if (!defined $device->{"exclude_group"}) {
            $device->{"exclude_group"} = [];
        }

        # Associate device with its device group.
        my $name = $self->{'device'}->{$device->{'address'}}->{'device_group'};
        push(@{$self->{'device_group'}->{$name}->{'devices'}},
             $self->{'device'}->{$device->{'address'}});
    }
}

=head2 Save

Saves YAML to file.

=cut
sub Save {
    my $self = shift;
    my $path = shift;
    if (!defined $path) {
        if (!defined $self->{'path'}) {
            return 0;
        } else {
            $path = $self->{'path'};
        }
    }

    my $result = {};

    $result->{'frontend'}      = $self->{'frontend'};
    $result->{'general'}       = $self->{'general'};
    $result->{'command_group'} = $self->{'command_group'};

    $result->{'device_group'} = [];
    my $groups = $self->DeviceGroups();
    foreach my $group (@{$groups}) {
        my $new = { name => $group->{'name'},
                    display => $group->{'display'},
                    description => $group->{'description'}
                  };
        push(@{$result->{'device_group'}}, $new);
    }

    $result->{'device'} = [];
    my $devices = $self->SortedDevices();
    foreach my $device (@{$devices}) {
        if (!defined $device->{'external_id'}) {
            $device->{'external_id'} = -1;
        }

        my $new = { name => $device->{'name'},
                    address => $device->{'address'},
                    city => $device->{'city'},
                    device_group => $device->{'device_group'},
                    method => $device->{'method'},
                    password => $device->{'password'},
                    state => $device->{'state'},
                    type => $device->{'type'},
                    username => $device->{'username'},
                    command_group => $device->{'command_group'},
                    exclude_group  => $device->{'exclude_group'},
                    external_id    => $device->{'external_id'}
                  };
        push(@{$result->{'device'}}, $new);
    }

    YAML::DumpFile($path, $result);
    return 1;
}

=head2 Redacts

Returns a list of redact regexs.

=cut
sub Redacts {
    my $self = shift;
    return \@{$self->{'general'}->{'redact'}};
}

=head2 CommandsInGroup

Returns a list of commands in command group $name.

=cut
sub CommandsInGroup {
    my $self = shift;
    my $name = shift;

    if (defined $self->{'command_group'}->{$name}) {
        return \@{$self->{'command_group'}->{$name}};
    } else {
        return [];
    }
}

=head2 Device

Returns the device with address $name.

=cut
sub Device {
    my $self = shift;
    my $name = shift;

    return $self->{'device'}->{$name};
}

=head2 DeviceByExternalId

Returns the device with external id $external_id.

=cut
sub DeviceByExternalId {
    my $self        = shift;
    my $external_id = shift;

    foreach my $addr (keys %{$self->{'device'}}) {
        my $device = $self->{'device'}->{$addr};
        if ($device->{'external_id'} == $external_id) {
            return $device;
        }
    }

    return undef;
}

=head2 PutDevice

If the device already exists and new_address is in data. Data will be
reindexed under new_address.

    {
        name          => $device->{'name'}
        address       => $device->{'address'}
        new_address   => $device->{'new_address'}
        city          => $device->{'city'}
        device_group  => $device->{'device_group'}
        method        => $device->{'method'}
        password      => $device->{'password'}
        state         => $device->{'state'}
        type          => $device->{'type'}
        username      => $device->{'username'}
        command_group => $device->{'command_group'}
        exclude_group => $device->{'exclude_group'}
        external_id   => $device->{'external_id'}
    }

=cut

sub PutDevice {
    my $self = shift;
    my $data = shift;

    my $name = $data->{'address'};
    my $new_address = $data->{'new_address'};

    if (!defined $self->{'device'}->{$name}) {
        $self->{'device'}->{$name} = $data;
        $self->{'device'}->{$name}->{'position'} = 0;

        if (defined $self->{'device'}->{$name}->{'new_address'}) {
            delete $self->{'device'}->{$name}->{'new_address'};
        }

        return 1;
    }

    foreach my $k (keys %{$self->{'device'}->{$name}}) {
        if (defined $data->{$k}) {
            $self->{'device'}->{$name}->{$k} = $data->{$k};
        }
    }

    if (defined $new_address && ($new_address ne $name)) {
        $self->{'log'}->info("New address $new_address for $name received.");
        $self->{'device'}->{$new_address} = $self->{'device'}->{$name};
        $self->{'device'}->{$new_address}->{'address'} = $new_address;

        delete $self->{'device'}->{$name};
    }

    return 1;
}

=head2 Devices

Returns a copy of the devices in this config as a hash.

=cut
sub Devices {
    my $self = shift;
    return \%{$self->{'device'}};
}

=head2 SortedDevices

=cut
sub SortedDevices {
    my $self = shift;

    my $result = [];
    foreach my $name (sort { $self->{'device'}->{$a}->{'position'} <=> $self->{'device'}->{$b}->{'position'} } keys %{$self->{'device'}}) {
        push(@{$result}, $self->{'device'}->{$name});
    }
    return $result;
}

=head2 DeviceGroups

Returns an array of the device groups in this config.

=cut
sub DeviceGroups {
    my $self = shift;
    my %params = @_;

    my $result = [];
    foreach my $name (sort { $self->{'device_group'}->{$a}->{'position'} <=> $self->{'device_group'}->{$b}->{'position'} } keys %{$self->{'device_group'}}) {
        my $group = $self->{'device_group'}->{$name};
        if ($params{'sort_devices'}) {
            my @devices = sort { $a->{'name'} cmp $b->{'name'} } @{$group->{'devices'}};
            $group->{'devices'} = \@devices;
        }
        push(@{$result}, $group);
    }
    return $result;
}

sub PutDeviceGroup {
    my $self = shift;
    my $name = shift;

    if (defined $self->{'device_group'}->{$name}) {
        # Device group already exists.
        return 0;
    }

    $self->{'device_group'}->{$name} = { name => $name,
                                         description => '',
                                         devices => [],
                                         display => 1,
                                         position => 0 };
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

=head2 DeviceExcludeCommands

Returns the allowed commands for the device named $name.

=cut
sub DeviceExcludeCommands {
    my $self = shift;
    my $name = shift;

    my $result = [];
    my $groups = $self->{'device'}->{$name}->{'exclude_group'};

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
    return $self->{'general'}->{'logging'};
}

=head2 MaxLines

Returns the maximum number of lines allowed in a switch response.

=cut
sub MaxLines {
    my $self = shift;
    return $self->{'general'}->{'max_lines'};
}

=head2 MaxRate

Returns the maximum rate in seconds that requests may be made.

=cut
sub MaxRate {
    my $self = shift;
    return $self->{'general'}->{'max_rate'};
}

=head2 MaxTimeout

Returns the maximum number of seconds to wait before timing out.

=cut
sub MaxTimeout {
    my $self = shift;
    return $self->{'general'}->{'max_timeout'};
}

=head2 NetworkName

Returns the name of the network.

=cut
sub NetworkName {
    my $self = shift;
    return $self->{'frontend'}->{'network_name'};
}

=head2 NOCName

Returns the name of the NOC.

=cut
sub NOCName {
    my $self = shift;
    return $self->{'frontend'}->{'noc_name'};
}

=head2 NOCMail

Returns the email of the NOC.

=cut
sub NOCMail {
    my $self = shift;
    return $self->{'frontend'}->{'noc_mail'};
}

=head2 NOCSite

Returns a link to the NOC website.

=cut
sub NOCSite {
    my $self = shift;
    return $self->{'frontend'}->{'noc_site'};
}

=head2 NOCHelp

Returns a help message.

=cut
sub NOCHelp {
    my $self = shift;
    return $self->{'frontend'}->{'help'};
}

=head2 ShowDropdown

Returns 1 if device menues should be shown.

=cut
sub ShowDropdown {
    my $self = shift;
    return $self->{'frontend'}->{'dropdown'};
}

return 1;
