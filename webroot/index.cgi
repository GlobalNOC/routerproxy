#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use JSON;
use FindBin;
use FileHandle;
use Encode;
use Template;
use XML::Simple;
use Data::Dumper;
use Time::ParseDate;

use GRNOC::RouterProxy;
use GRNOC::RouterProxy::Logger;
use GRNOC::RouterProxy::Config;
use GRNOC::RouterProxy::Commands;
use GRNOC::Config;

use GRNOC::TL1;
use GRNOC::TL1::Device::Nortel::OME6500;
use GRNOC::TL1::Device::Nortel::HDXc;
use GRNOC::TL1::Device::Cisco::ONS15454;
use GRNOC::TL1::Device::Ciena::CoreDirector;

# Set the home directory relative to this script
my $home_dir = "$FindBin::Bin/../";
$ENV{'HOME'} = $home_dir;

# Initialize the logger
Log::Log4perl::init('/etc/grnoc/routerproxy/logging.conf');
my $logger = Log::Log4perl->get_logger('GRNOC.RouterProxy');

# Check for and import JUNOS Script support
my $hasJunoscript;
BEGIN {
    eval {
        require JUNOS::Device;
    };
    if ($@) {
        $hasJunoscript = 0;
    } else {
        $hasJunoscript = 1;
        JUNOS::Device->import;
    }
}

# Check for and import IOS XR XML support
my $hasIosXML;
BEGIN {
    eval {
        require Cisco::IOS_XR;
    };
    if ($@) {
        $hasIosXML = 0;
    } else {
        $hasIosXML = 1;
        Cisco::IOS_XR->import;
    }
}

# Use the fast XML parser
local $ENV{'XML_SIMPLE_PREFERRED_PARSER'} = 'XML::Parser';

# Init CGI
my $cgi = CGI->new();

# Confirm the mappings config path or error out
my $config_path = getMappedConfig($ENV{'REQUEST_URI'}, "/etc/grnoc/routerproxy/mappings.xml");
unless (defined($config_path) && -e $config_path) {
    my $msg = "Configuration for $ENV{'REQUEST_URI'} not found. Check mapping file '$config_path'";
    $logger->error($msg);
    print $cgi->header();
    print $cgi->start_html();
    print "<h2>$msg</h2>";
    print $cgi->end_html();
    exit 1;
}

# Read the config and store devices by address
my $conf = GRNOC::RouterProxy::Config->New($config_path);
my $devices     = $conf->Devices();
my $logfile     = $conf->LogFile();
my $maxlines    = $conf->MaxLines();
my $timeout     = $conf->MaxTimeout();
my $spamSeconds = $conf->MaxRate();
my $enable_menu = $conf->ShowDropdown();
my $remoteIP    = $ENV{'REMOTE_ADDR'};


# Handles errors for undefined methods
sub getError {
    my $msg = "The requested method does not exist";
    $logger->error($msg);
    print $cgi->header(-type => "text/html", -status => "501");
    print $msg;
}


# Prints HTML to STDOUT, called immediately after definition
sub makeHTML2 {
    my $template = Template->new({ABSOLUTE => 1});
    my $input    = "/usr/share/grnoc/routerproxy/templates/index.tt";

    # If $handler is defined outside the makeHTML2 subroutine this error is returned:
    # Can't use string ("") as a subroutine ref while "strict refs" in use at /gnoc/routerproxy/webroot/index.cgi line 302.
    my $handler = {
        device => \&getDevice,
        devices => \&getDevices,
        error  => \&getError,
        submit => \&getResponses
    };

    # Check if a method has been called on this CGI.
    my $method = $cgi->param('method');
    if (defined $method) {
        if (!defined $handler->{$method}) {
            $handler->{"error"}->();
        } else {
            $handler->{$method}->();
        }
        # HTML has been printed; Return.
        return;
    }

    my $html = "";
    my $vars = {
        network_name    => $conf->NetworkName(),
        primary_color   => $conf->PrimaryColor(),
        secondary_color => $conf->SecondaryColor(),
        noc_mail        => $conf->NOCMail(),
        noc_name        => $conf->NOCName(),
        noc_site        => $conf->NOCSite(),
        groups          => $conf->DeviceGroups(sort_devices => 1)
    };
    $template->process($input, $vars, \$html);
    print $cgi->header(-type => "text/html", -status => "200");
    print $html;
    return;
}
makeHTML2();


# Gets a YAML config using the mappings config
sub getMappedConfig {
    my ($url, $map_file) = @_;

    # Confirm the mapping config exists
    unless (-e $map_file) {
        $logger->error("Mapping file '$map_file' not found.\n");
        return undef;
    }

    my $config  = GRNOC::Config->new( config_file => $map_file, force_array => 1 );
    my $entries = $config->get( '/mappings/map' );
    foreach my $entry ( @$entries ) {
        my $regexp = $entry->{'regexp'};
        if ( $url =~ /$regexp/ ) {
            return $entry->{'config_location'};
        }
    }
    return undef;
}


# Gets device metadata and prints it on the page
sub getDevice {
    my $device = $cgi->param("device");

    if (!defined $device) {
        my $msg = "Request is missing the 'device' parameter";
        $logger->error($msg);
        print $cgi->header(-type => "text/html", -status => "400");
        print $msg;
        return;
    }

    # Create a copy of the device data and remove all secrets.
    my $data = $devices->{$device};

    if (!defined $data) {
        my $msg = "The specified device '$device' does not exist";
        $logger->error($msg);
        print $cgi->header(-type => "text/html", -status => "200");
        print $msg;
        return;
    }

    # Set commands and menu flag
    $data->{"commands"}    = $conf->DeviceCommands($data->{"address"});
    $data->{"enable_menu"} = $enable_menu;

    # Remove sensitive data fields
    delete $data->{"username"};
    delete $data->{"password"};
    delete $data->{"method"};
    delete $data->{"command_group"};
    delete $data->{"exclude_group"};

    # Print the data as encoded JSON
    print $cgi->header(-type => "text/html", -status => "200");
    print encode_json($data);
}


# getDevice for many devices
sub getDevices {
    my @device_keys = keys %$devices;
    my @result = ();
    foreach my $key (keys %$devices) {
        my $data = $devices->{$key};
        $data->{"commands"}    = $conf->DeviceCommands($data->{"address"});
        $data->{"enable_menu"} = $enable_menu;
        
        delete $data->{"username"};
        delete $data->{"password"};
        delete $data->{"method"};
        delete $data->{"command_group"};
        delete $data->{"exclude_group"};
        push @result, $data;
    }
    print $cgi->header(-type => "text/html", -status => "200");
    print encode_json(\@result);
}


# Filters out spam requests by comparing last op time and $now using logs
sub filterSpam {
    # Get the last log time from the logfile
    my $last = GRNOC::RouterProxy::Logger::getLastTime($logfile);

    # Don't try to enforce spam limits for new logfiles
    return unless $last;

    # Return a warning of how log to wait if the last command was less than spamSeconds before
    my $diff = time() - $last;
    if ($diff < $spamSeconds) {
        my $wait = $spamSeconds - $diff;
        return "Please wait $wait seconds before sending another command.";
    }
    return;
}


# Handle the request for data from a device for a command and return the response to the page
sub getResponses {
    my $address   = $cgi->param("device");
    my $command   = $cgi->param("command");
    my $arguments = $cgi->param("arguments") || "";
    my $menu_req  = $cgi->param("menu") || 0;

    # Confirm that the request has an address and command
    if (!defined $address || !defined $command) {
        my $msg = "Request is missing either the 'device' or 'command' parameters";
        $logger->error($msg);
        print $cgi->header(-type => "text/html", -status => "400" );
        print $msg;
        return;
    }

    # Get the device data from the hash and confirm it is not empty
    my $device = $devices->{$address};
    if (!defined $device) {
        my $msg = "The specified device '$device' does not exist";
        $logger->error($msg);
        print $cgi->header(-type => "text/html", -status => "200" );
        print $msg;
        return;
    }

    # Route the request and return the response to the page
    my $response = "";
    if ($menu_req && $enable_menu && $device->{"type"} eq "junos") {
        $response = getMenuResponse($command, $device);
    } elsif ($menu_req && $enable_menu && $device->{"type"} eq "iosxr") {
        $response = getIosMenuResponse($command, $device);
    } elsif ($menu_req && $enable_menu && $device->{"type"} eq "hdxc") {
        $response = getHdxcMenuResponse($command, $device);
    } elsif ($menu_req && $enable_menu && $device->{"type"} eq "ons15454") {
        $response = getOnsMenuResponse($command, $device);
    } elsif ($menu_req && $enable_menu && $device->{"type"} eq "ome") {
        $response = getOmeMenuResponse($command, $device);
    } elsif ($menu_req && $enable_menu && $device->{"type"} eq "ciena") {
        $response = getCienaMenuResponse($command, $device);
    } elsif ($menu_req) {
        $response = "Menu-enabled requests are not configured for this device. Please reload the page.";
    } else {
        $response = getResponse($command, $arguments, $device);
    }
    print $cgi->header(-type => "text/html", -status => "200");
    print "$response";
}


sub getResponse {
    my $command   = shift;
    my $arguments = shift;
    my $device    = shift;

    my $spam_warning = filterSpam();
    return $spam_warning if ($spam_warning);
    
    if (!validCommand($command, $arguments, $device) && $device->{'type'} ne 'TEST') {
        my $msg = "Attempt to issue disabled command '$command' for $device->{'name'}";
        $logger->info($msg);
        return $msg;
    }

    # Append arguments to the command if any
    $command = $command . " " . $arguments if ($arguments ne "");

    # Add the command to the history log
    GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device->{'address'}, $command . " " . $arguments);

    # Fix encoding (legacy)
    my $username = $device->{'username'};
    my $password = $device->{'password'};
    Encode::from_to($username, 'utf8', 'iso-8859-1');
    Encode::from_to($password, 'utf8', 'iso-8859-1');

    my $proxy = GRNOC::RouterProxy->new(
        hostname    => $device->{'address'},
        port        => $device->{'port'},
        method      => $device->{'method'},
        type        => $device->{'type'},
        username    => $username,
        password    => $password,
        maxlines    => $maxlines,
        config_path => $config_path,
        timeout     => $timeout
    );
    my $result = $proxy->command($command);

    # End the timer if the command was successful and return the result
    alarm(0);
    return $result;
}


sub tl1Connect {
    my ($cmd, $device) = @_;

    # Add a history log entry for this command and device
    GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

    # Create a TL1 connection for issuing commands
    $logger->debug("Establishing TL1 connection to $device->{'name'}");
    my $tl1 = GRNOC::TL1->new(
        username => $device->{'username'},
        password => $device->{'password'},
        type     => $device->{'type'},
        host     => $device->{'address'},
        port     => $device->{'port'},
        ctag     => 1337
    );
    $tl1->connect();
    $tl1->login();

    # Return the TL1 connection
    return $tl1;
}


sub getCienaMenuResponse {
    my ($cmd, $device) = @_;
    my @rows;
    my $result;

    my $spam_warning = filterSpam();
    return $spam_warning if ($spam_warning);

    # Get the device from the hash of devices if it exists or return a warning
    $device = $devices->{$device} if (exists($devices->{$device}) && defined($devices->{$device}));
    if (!defined($device)) {
        my $msg = "The requested device \"$device->{'name'}\" does not exist. Please reload the page.";
        $logger->warn($msg);
        return $msg;
    }

    my $tl1 = tl1Connect($cmd, $device);

    if ($cmd eq "alarms") {
        @rows = $tl1->get_alarms();
        $result = retrAlmAll3(@rows);
    }
    elsif ($cmd eq "inventory") {
        @rows = $tl1->get_inventory();
        $result = retrEqpt(@rows);
    }
    elsif ($cmd eq "circuits") {
        @rows = $tl1->get_cross_connects();
        $result = retrCrs2(@rows);
    }
    return $result;
}


sub getOnsMenuResponse {
    my ($cmd, $device) = @_;
    my @rows;
    my $result;

    my $spam_warning = filterSpam();
    return $spam_warning if ($spam_warning);

    # Get the device from the hash of devices if it exists or return a warning
    $device = $devices->{$device} if (exists($devices->{$device}) && defined($devices->{$device}));
    if (!defined($device)) {
        my $msg = "The requested device \"$device->{'name'}\" does not exist. Please reload the page.";
        $logger->warn($msg);
        return $msg;
    }

    my $tl1 = tl1Connect($cmd, $device);

    if ($cmd eq "alarms") {
        @rows = $tl1->get_alarms();
        $result = retrAlmAll(@rows);
    }
    elsif ($cmd eq "circuits") {
        @rows = $tl1->get_cross_connects();
        $result = retrCrs(@rows);
    }
    elsif ($cmd eq "inventory") {
        @rows = $tl1->get_inventory();
        $result = retrInv(@rows);
    }
    return $result;
}


sub getOmeMenuResponse {
    my ($cmd, $device) = @_;
    my @rows;
    my $result;

    my $spam_warning = filterSpam();
    return $spam_warning if ($spam_warning);

    # Get the device from the hash of devices if it exists or return a warning
    $device = $devices->{$device} if (exists($devices->{$device}) && defined($devices->{$device}));
    if (!defined($device)) {
        my $msg = "The requested device \"$device->{'name'}\" does not exist. Please reload the page.";
        $logger->warn($msg);
        return $msg;
    }

    my $tl1 = tl1Connect($cmd, $device);

    if ($cmd eq "alarms") {
        @rows = $tl1->get_alarms();
        $result = retrAlmAll2(@rows);
    }
    elsif ($cmd eq "circuits") {
        @rows = $tl1->get_cross_connects();
        $result = retrCrsAll2(@rows);
    }
    elsif ($cmd eq "inventory") {
        @rows = $tl1->get_inventory();
        $result = retrInventory2(@rows);
        # ons15454$result = retrInv(@rows);
    }
    return $result;
}


sub getHdxcMenuResponse {
    my ($cmd, $device) = @_;
    my @rows;
    my $result;

    my $spam_warning = filterSpam();
    return $spam_warning if ($spam_warning);

    # Get the device from the hash of devices if it exists or return a warning
    $device = $devices->{$device} if (exists($devices->{$device}) && defined($devices->{$device}));
    if (!defined($device)) {
        my $msg = "The requested device \"$device->{'name'}\" does not exist. Please reload the page.";
        $logger->warn($msg);
        return $msg;
    }

    my $tl1 = tl1Connect($cmd, $device);

    if ($cmd eq "alarms") {
        @rows = $tl1->get_alarms();
        $result = retrAlmAll(@rows);
    }
    elsif ($cmd eq "circuits") {
        @rows = $tl1->get_cross_connects();
        $result = retrCrsAll(@rows);
    }
    elsif ($cmd eq "inventory") {
        @rows = $tl1->get_inventory();
        if ($device->{'type'} eq "hdxc") {
            $result = retrInventory(@rows);
        }
        elsif ($device->{'type'} eq "ome") {
            $result = retrInventory2(@rows);
        }
        else {
            $result = retrInv(@rows);
        }
    }
    return $result;
}


sub getIosMenuResponse {
    my ($cmd, $device) = @_;
    my $result;

    my $spam_warning = filterSpam();
    return $spam_warning if ($spam_warning);

    # Return early if IOS XR XML isn't installed
    return "IOS XR XML must be installed" if (!$hasIosXML);

    # Get the device from the hash of devices if it exists or return a warning
    $device = $devices->{$device} if (exists($devices->{$device}) && defined($devices->{$device}));
    if (!defined($device)) {
        my $msg = "The requested device \"$device->{'name'}\" does not exist. Please reload the page.";
        $logger->warn($msg);
        return $msg;
    }

    GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

    # Get the device name to simplify formatting
    my $name = $device->{'name'};

    # Connect to the device
    my $cisco = Cisco::IOS_XR->new(
        host               => $device->{'address'},
        transport          => $device->{'method'},
        username           => $device->{'username'},
        password           => $device->{'password'},
        connection_timeout => $timeout
    );

    if ($cmd eq "bgp") {
        my $oper = Cisco::IOS_XR::Data::Operational();
        $result = $oper->BGP->DefaultVRF->NeighborTable->get_keys();
        $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>BGP Configuration For $name</td></tr></table><br />" . bgp($result, $oper);
    }
    elsif ($cmd eq "isis") {
        my $xml = '<?xml version="1.0" encoding="UTF-8"?>
                            <Request MajorVersion="1" MinorVersion="0">
                             <Get>
                              <Configuration>
                               <ISIS>
                               </ISIS>
                              </Configuration>
                             </Get>
                            </Request>';
        $result = XMLin($cisco->send_req($xml)->to_string, forcearray => 1);
        $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>ISIS Configuration For $name</td></tr></table><br />" . isis($result);
    }
    elsif ($cmd eq "msdp") {
        my $xml = '<?xml version="1.0" encoding="UTF-8"?>
                            <Request MajorVersion="1" MinorVersion="0">
                             <Get>
                              <Configuration>
                               <MSDP>
                               </MSDP>
                              </Configuration>
                             </Get>
                            </Request>';
        $result = XMLin($cisco->send_req($xml)->to_string, forcearray => 1);
        $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>MSDP Configuration For $name</td></tr></table><br />" . msdp($result);
    }
    elsif ($cmd eq "interfaces") {
        my $xml = '<?xml version="1.0" encoding="UTF-8"?>
                            <Request MajorVersion="1" MinorVersion="0">
                             <Get>
                              <Configuration>
                               <InterfaceConfigurationTable>
                               </InterfaceConfigurationTable>
                              </Configuration>
                             </Get>
                            </Request>';
        $result = XMLin($cisco->send_req($xml)->to_string, forcearray => 1);
        $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>Interfaces For $name</td></tr></table><br />" . interfaces($result);
    }
    elsif ($cmd eq "inventory") {
        my $xml = '<?xml version="1.0" encoding="UTF-8"?>
                            <Request MajorVersion="1" MinorVersion="0">
                             <CLI>
                              <Exec>
                                show inventory
                              </Exec>
                             </CLI>
                            </Request>';
        $result = XMLin($cisco->send_req($xml)->to_string, forcearray => 1);
        $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>Interfaces For $name</td></tr></table><br />" . inventory($result);
    }
    elsif ($cmd eq "ipv6Neighbors") {
        my $xml = '<?xml version="1.0" encoding="UTF-8"?>
                            <Request MajorVersion="1" MinorVersion="0">
                             <CLI>
                              <Exec>
                                show ipv6 neighbors
                              </Exec>
                             </CLI>
                            </Request>';
        $result = XMLin($cisco->send_req($xml)->to_string, forcearray => 1);
        $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>IPv6 Neighbors For $name</td></tr></table><br />" . ipv6Neighbors($result);
    }
    return $result;
}


# Helper function to get and format JUNOS command results
sub junosResult {
    my ($junos, $cmd, $method, $msg) = @_;
    my $result = $junos->command($cmd)->toString;
    $result =~ s/junos://g;
    my $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>$msg</td></tr></table><br />" . $method->($xml);
}


sub getMenuResponse {
    my ($cmd, $device) = @_;
    my $result;

    # Return early if JUNOS Script isn't installed
    return ("Junoscript must be installed", "") if (!$hasJunoscript);

    my $spam_warning = filterSpam();
    return $spam_warning if ($spam_warning);
  
    GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

    # Return a warning if the device doesn't exist
    if (!defined($device)) {
        my $msg = "The requested device \"$device\" does not exist. Please reload the page.";
        $logger->warn($msg);
        return $msg;
    }

    # Issue the command with JUNOSCRIPT
    my %info = (
        hostname => $device->{'address'},
        access   => $device->{'method'},
        login    => encode("utf8", $device->{'username'}),
        password => encode("utf8", $device->{'password'}),
    );
    my $junos = new JUNOS::Device(%info);

    # Route menu commands to the right JUNOS command and processing method
    if ($cmd eq "bgp") {
        $result = junosResult($junos, 'show bgp summary', \&showBgpSummary, "BGP Summary for $device->{'name'}");
    }
    elsif ($cmd eq "bootMessages") {
        $result = junosResult($junos, 'show system boot-messages', \&showSystemBootMessages, "System Boot Messages for $device->{'name'}");
    }
    elsif ($cmd eq "environment") {
        $result = junosResult($junos, 'show chassis environment', \&showChassisEnvironment, "Chassis Environment for $device->{'name'}");
    }
    elsif ($cmd eq "filesystem") {
        $result = junosResult($junos, 'show system storage', \&showSystemStorage, "System Storage for $device->{'name'}");
    }
    elsif ($cmd eq "interfaces") {
        $result = junosResult($junos, 'show interfaces', \&showInterfaces, "Interfaces for $device->{'name'}");
    }
    elsif ($cmd eq "inventory") {
        $result = junosResult($junos, 'show chassis hardware', \&showChassisHardware, "Chassis Hardware for $device->{'name'}");
    }
    elsif ($cmd eq "ipv6Neighbors") {
        $result = junosResult($junos, 'show ipv6 neighbors', \&showIpv6Neighbors, "IPv6 Neighbors for $device->{'name'}");
    }
    elsif ($cmd eq "isis") {
        $result = junosResult($junos, 'show isis adjacency', \&showIsisAdjacency, "ISIS Adjacencies for $device->{'name'}");
    }
    elsif ($cmd eq "msdp") {
        $result = junosResult($junos, 'show msdp detail', \&showMsdpDetail, "MSDP Details for $device->{'name'}");
    }
    elsif ($cmd eq "multicastStatistics") {
        $result = junosResult($junos, 'show multicast statistics', \&showMulticastStatistics, "Multicast Statistics for $device->{'name'}");
    }
    elsif ($cmd eq "snmpStatistics") {
        $result = junosResult($junos, 'show snmp statistics', \&showSnmpStatistics, "SNMP Statistics for $device->{'name'}");
    }
    elsif ($cmd eq "version") {
        $result = junosResult($junos, 'show version', \&showVersion, "Version for $device->{'name'}");
    }
    return $result;
}


sub validCommand {
    my $command = shift;
    my $args    = shift;
    my $device  = shift;
    my $type    = $device->{"type"};

    # Do not allow non alphanumeric-ish chars.
    # This prevents circumventing multiple / altered commands.
    if ($command =~ /[\x00-\x1f]/ || $command =~ /\x7f/ ||
        $args =~ /[\x00-\x1f]/ || $args =~ /\x7f/) {
        return 0;
    }

    # Do not allow regexp due to IOS vulnerability.
    if ($args =~ m/regexp/i) {
        return 0;
    }
    # Do not allow piping to other commands besides display and match.
    if ($args =~ m/\|/ && ($args =~ m/.*\|.*\|.*/ || !($args =~ m/display/ or $args =~ m/match/)) ) {
        return 0;
    }

    # Append command arguments to the command if any
    $command = $command . " " . $args if ($args ne "");

    my $validCommands   = $conf->DeviceCommands($device->{"address"});
    my $excludeCommands = $conf->DeviceExcludeCommands($device->{"address"});

    # Check if the command matches any exluded ones
    foreach my $excludeCommand (@{$excludeCommands}) {
        return 0 if ($command =~ /$excludeCommand/);
    }

    foreach my $validCommand (@{$validCommands}) {
        # For layer2/3, accept anything with the prefix of a valid command
        if ($type eq "ciena" || $type eq "hdxc" || $type eq "ons15454" || $type eq "ome") {
            return 1 if ($command eq $validCommand);
        } else {
            $validCommand = "^$validCommand";
            return 1 if ($command =~ m/$validCommand/);
        }
    }
    return 0;
}


sub _parseLocationData {
    my %args = @_;
    my $city  = $args{'city'};
    my $state = $args{'state'};

    my @loc_array = ($city, $state);

    my $location_data = "";
    for (my $i = 0; $i <= $#loc_array; $i++) {
        my $loc_element = $loc_array[$i];

        # add opeing paren if first element is defined
        if($i == 0 && (ref $loc_array[$i] ne ref {} ) ) {
            $location_data .= "(";
        }
        # add element if it's defined
        if(ref $loc_array[$i] ne ref {}) {
            $location_data .= $loc_array[$i];
        }
        # determin whether to add aa comma or close off parens
        if( ($i) >= $#loc_array ) {
            $location_data .= ")";
        }else {
            if( ref $loc_array[$i + 1] ne ref {}) {
                $location_data .= ", ";
            }
        }
    }
    return $location_data;
}
