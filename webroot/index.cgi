#!/usr/bin/perl
use warnings;

use FindBin;

use CGI;
use FileHandle;
use XML::Simple;
use GRNOC::RouterProxy;
use GRNOC::RouterProxy::Config;
use GRNOC::RouterProxy::Commands;
use Encode;
use Data::Dumper;
use GRNOC::Config;
use Template;

use JSON;

# set our home directory relative to our script
my $home_dir = "$FindBin::Bin/../";
$ENV{'HOME'} = $home_dir;

# do they have Junoscript installed?
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

# do they have IOS XR XML installed?
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

use GRNOC::TL1;
use GRNOC::TL1::Device::Nortel::OME6500;
use GRNOC::TL1::Device::Nortel::HDXc;
use GRNOC::TL1::Device::Cisco::ONS15454;
use GRNOC::TL1::Device::Ciena::CoreDirector;

use GRNOC::RouterProxy::Logger;
use Time::ParseDate;

use strict;

# use fast XML parser
local $ENV{'XML_SIMPLE_PREFERRED_PARSER'} = 'XML::Parser';

my $cgi = CGI->new();
my $config_path = ConfigChooser( $ENV{'REQUEST_URI'},
                                 "/etc/grnoc/routerproxy/mappings.xml");

unless (defined($config_path) && -e $config_path) {
    warn ("Please check mapping file. The config file for this url cannot be located\n");
    print $cgi->header();
    print $cgi->start_html();
    print "<H2>Please check mapping file. The config file for this url cannot be located</H2>";
    print $cgi->end_html();
    
    exit 1;
}

my $conf = GRNOC::RouterProxy::Config->New($config_path);

# A little hack to store devices by address. Should be changed to use
# device name in the future.
my $devices = $conf->Devices();

my $logfile                     = $conf->LogFile();
my $maxlines                    = $conf->MaxLines();
my $timeout                     = $conf->MaxTimeout();
my $spamSeconds                 = $conf->MaxRate();
my $global_enable_menu_commands = $conf->ShowDropdown();

my $remoteIP = $ENV{'REMOTE_ADDR'};


# Prints HTML to STDOUT
makeHTML2();


sub ConfigChooser {
    my $url      = shift;
    my $map_file = shift;
 
    # If mapping file is not found
    unless (-e $map_file) {
        warn ("Mapping file is not found.\n");
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

sub getDevice {
    my $device = $cgi->param("device");
    if (!defined $device) {
        print $cgi->header(-type => "text/html",
                           -status => "400" );
        print "Request requires parameters: device";
        return;
    }

    # Create a copy of the device data and remove all secrets.
    my $data = $devices->{$device};
    if (!defined $data) {
        print $cgi->header(-type => "text/html",
                           -status => "200" );
        print "The specified device does not exist.";
        return;
    }

    $data->{"commands"}    = $conf->DeviceCommands($data->{"address"});
    $data->{"enable_menu"} = $global_enable_menu_commands;

    delete $data->{"username"};
    delete $data->{"password"};
    delete $data->{"method"};
    delete $data->{"command_group"};
    delete $data->{"exclude_group"};

    print $cgi->header(-type => "text/html",
                       -status => "200" );
    print encode_json($data);
}

sub getResponses {
    my $address   = $cgi->param("device");
    my $command   = $cgi->param("command");
    my $arguments = $cgi->param("arguments") || "";
    my $menu_req  = $cgi->param("menu") || 0;

    if (!defined $address || !defined $command) {
        print $cgi->header(-type => "text/html",
                           -status => "400" );
        print "Request requires parameters: device, command";
        return;
    }

    my $device = $devices->{$address};
    if (!defined $device) {
        print $cgi->header(-type => "text/html",
                           -status => "200" );
        print "The specified device does not exist.";
        return;
    }

    my $menu_enabled = $global_enable_menu_commands;
    my $data         = "";

    if ($menu_req && $menu_enabled && $device->{"type"} eq "junos") {
        $data = getMenuResponse($command, $device);
    } elsif ($menu_req && $menu_enabled && $device->{"type"} eq "iosxr") {
        $data = getIosMenuResponse($command, $device);
    } elsif ($menu_req && $menu_enabled && $device->{"type"} eq "hdxc") {
        $data = getHdxcMenuResponse($command, $device);
    } elsif ($menu_req && $menu_enabled && $device->{"type"} eq "ons15454") {
        $data = getOnsMenuResponse($command, $device);
    } elsif ($menu_req && $menu_enabled && $device->{"type"} eq "ome") {
        $data = getOmeMenuResponse($command, $device);
    } elsif ($menu_req && $menu_enabled && $device->{"type"} eq "ciena") {
        $data = getCienaMenuResponse($command, $device);
    } elsif ($menu_req) {
        $data = "Menu enabled requests are not configured for this device. Please reload the page.";
    } else {
        $data = getResponse($command, $arguments, $device);
    }

    print $cgi->header(-type => "text/html",
                       -status => "200" );
    print "$data";
}


sub getResponse {
    my $command   = shift;
    my $arguments = shift;
    my $device    = shift;

    my $last = GRNOC::RouterProxy::Logger::getLastTime($logfile);
    my $now  = time();
    my $diff = $now - $last;
    if ($diff < $spamSeconds) {
        my $wait = $spamSeconds - $diff;
        return "Please wait $wait seconds before sending another command.";
    }

    GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device->{'address'}, $command . " " . $arguments);
    if (!validCommand($command, $arguments, $device)) {
        return "Disabled Command.";
    }

    if ($arguments ne "") {
        $command = $command . " " . $arguments;
    }

    my $name     = $device->{'name'};
    my $hostname = $device->{'address'};
    my $method   = $device->{'method'};
    my $username = $device->{'username'};
    my $password = $device->{'password'};
    my $type     = $device->{'type'};
    my $port     = $device->{'port'};

    # Fix encoding. I don't know why. This is legecy.
    Encode::from_to($username, 'utf8', 'iso-8859-1');
    Encode::from_to($password, 'utf8', 'iso-8859-1');

    my $proxy = GRNOC::RouterProxy->new(
        hostname    => $hostname,
        port        => $port,
        username    => $username,
        password    => $password,
        method      => $method,
        type        => $type,
        maxlines    => $maxlines,
        config_path => $config_path,
        timeout     => $timeout
    );
    my $result = $proxy->command($command);

    # End the timer if the command was successful.
    alarm(0);
    return $result;
}

sub getError {
    print $cgi->header(-type => "text/html",
                       -status => "501" );
    print "The requested method does not exist.";
}

sub makeHTML2 {
    my $tt = Template->new({ ABSOLUTE => 1 });
    my $input = "/usr/share/grnoc/routerproxy/templates/index.tt";

    # If $handler is defined outside the makeHTML2 subroutine an error
    # is returned.
    #
    # Can't use string ("") as a subroutine ref while "strict refs" in
    # use at /gnoc/routerproxy/webroot/index.cgi line 302.
    my $handler = { device => \&getDevice,
                    error  => \&getError,
                    submit => \&getResponses
                  };

    # Check if a method has been called on this CGI.
    my $method = $cgi->param('method');
    if (defined $method) {
        if (!defined  $handler->{$method}) {
            $handler->{"error"}->();
        } else {
            $handler->{$method}->();
        }
        # HTML has been printed; Return.
        return;
    }

    my $html = "";
    my $vars = { network_name => $conf->NetworkName(),
                 noc_mail     => $conf->NOCMail(),
                 noc_name     => $conf->NOCName(),
                 noc_site     => $conf->NOCSite(),
                 groups       => $conf->DeviceGroups(sort_devices => 1)
               };
    $tt->process($input, $vars, \$html);

    print $cgi->header(-type => "text/html",
                       -status => "200" );
    print $html;
    return;
}

sub getCienaMenuResponse {

  my $cmd = shift;
  my $device = shift;

  my @rows;
  my $result;

  my $last = GRNOC::RouterProxy::Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return "Please wait $wait seconds before sending another command.";
  }
  GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return "Requested device is not configured.  Please reload the page.";
  }

  # use my TL1 module to issue the command
  my $name = $devices->{$device}->{'name'};
  my $hostname = $devices->{$device}->{'address'};
  my $method = $devices->{$device}->{'method'};
  my $username = $devices->{$device}->{'username'};
  my $password = $devices->{$device}->{'password'};
  my $type = $devices->{$device}->{'type'};
  my $port = $devices->{$device}->{'port'};

  my $tl1 = GRNOC::TL1->new(
                            username => $username,
                            password => $password,
                            type => $type,
                            host => $hostname,
                            port => $port,
                            ctag => 1337);

  $tl1->connect();
  $tl1->login();

  # alarms cmd
  if ($cmd eq "alarms") {

    @rows = $tl1->get_alarms();
    $result = retrAlmAll3(@rows);
  }

  # eqpt cmd
  elsif ($cmd eq "inventory") {

    @rows = $tl1->get_inventory();
    $result = retrEqpt(@rows);
  }

  # circuits cmd
  elsif ($cmd eq "circuits") {

    @rows = $tl1->get_cross_connects();
    $result = retrCrs2(@rows);
  }

  return $result;
}

sub getOnsMenuResponse {

  my $cmd = shift;
  my $device = shift;

  my @rows;
  my $result;

  my $last = GRNOC::RouterProxy::Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return "Please wait $wait seconds before sending another command.";
  }
  GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return "Requested device is not configured.  Please reload the page.";
  }

  # use my TL1 module to issue the command
  my $name = $devices->{$device}->{'name'};
  my $hostname = $devices->{$device}->{'address'};
  my $method = $devices->{$device}->{'method'};
  my $username = $devices->{$device}->{'username'};
  my $password = $devices->{$device}->{'password'};
  my $type = $devices->{$device}->{'type'};
  my $port = $devices->{$device}->{'port'};

  my $tl1 = GRNOC::TL1->new(
                            username => $username,
                            password => $password,
                            type => $type,
                            host => $hostname,
                            port => $port,
                            ctag => 1337);

  $tl1->connect();
  $tl1->login();

  # alarms cmd
  if ($cmd eq "alarms") {

    @rows = $tl1->get_alarms();
    $result = retrAlmAll(@rows);
  }

  # circuits cmd
  elsif ($cmd eq "circuits") {

    @rows = $tl1->get_cross_connects();
    $result = retrCrs(@rows);
  }

  # inventory cmd
  elsif ($cmd eq "inventory") {

    @rows = $tl1->get_inventory();
    $result = retrInv(@rows);
  }

  return $result;
}

sub getOmeMenuResponse {

  my $cmd = shift;
  my $device = shift;

  my @rows;
  my $result;

  my $last = GRNOC::RouterProxy::Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return "Please wait $wait seconds before sending another command.";
  }
  GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return "Requested device is not configured.  Please reload the page.";
  }

  # use my TL1 module to issue the command
  my $name = $devices->{$device}->{'name'};
  my $hostname = $devices->{$device}->{'address'};
  my $method = $devices->{$device}->{'method'};
  my $username = $devices->{$device}->{'username'};
  my $password = $devices->{$device}->{'password'};
  my $type = $devices->{$device}->{'type'};
  my $port = $devices->{$device}->{'port'};

  my $tl1 = GRNOC::TL1->new(
                            username => $username,
                            password => $password,
                            type => $type,
                            host => $hostname,
                            port => $port,
                            ctag => 1337);

  $tl1->connect();
  $tl1->login();

  # alarms cmd
  if ($cmd eq "alarms") {

    @rows = $tl1->get_alarms();
    $result = retrAlmAll2(@rows);
  }

  # circuits cmd
  elsif ($cmd eq "circuits") {

    @rows = $tl1->get_cross_connects();
    $result = retrCrsAll2(@rows);
  }

  # inventory cmd
  elsif ($cmd eq "inventory") {

    @rows = $tl1->get_inventory();
    $result = retrInventory2(@rows);
    # ons15454$result = retrInv(@rows);
  }

  return $result;
}

sub getHdxcMenuResponse {

  my $cmd = shift;
  my $device = shift;

  my @rows;
  my $result;

  my $last = GRNOC::RouterProxy::Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return "Please wait $wait seconds before sending another command.";
  }
  GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {
      return "Requested device is not configured.  Please reload the page.";
  }

  # use my TL1 module to issue the command
  my $name = $devices->{$device}->{'name'};
  my $hostname = $devices->{$device}->{'address'};
  my $method = $devices->{$device}->{'method'};
  my $username = $devices->{$device}->{'username'};
  my $password = $devices->{$device}->{'password'};
  my $type = $devices->{$device}->{'type'};
  my $port = $devices->{$device}->{'port'};

  my $tl1 = GRNOC::TL1->new(
                            username => $username,
                            password => $password,
                            type => $type,
                            host => $hostname,
                            port => $port,
                            ctag => 1337);

  $tl1->connect();
  $tl1->login();

  # alarms cmd
  if ($cmd eq "alarms") {

    @rows = $tl1->get_alarms();
    $result = retrAlmAll(@rows);
  }

  # circuits cmd
  elsif ($cmd eq "circuits") {

    @rows = $tl1->get_cross_connects();
    $result = retrCrsAll(@rows);
  }

  # inventory cmd
  elsif ($cmd eq "inventory") {

    @rows = $tl1->get_inventory();

    if ($type eq "hdxc") {
      $result = retrInventory(@rows);
    }
    elsif ($type eq "ome") {
      $result = retrInventory2(@rows);
    }
    else {
      $result = retrInv(@rows);
    }
  }

  return $result;
}

sub getIosMenuResponse {

  my $cmd = shift;
  my $device = shift;

  if (!$hasIosXML) {
    return "IOS XR XML must be installed.";
  }

  my $result;

  my $last = GRNOC::RouterProxy::Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return "Please wait $wait seconds before sending another command.";
  }
  GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return "Requested device is not configured.  Please reload the page.";
  }

  # use IOS XR XML to issue the command
  my $name = $devices->{$device}->{'name'};
  my $address = $devices->{$device}->{'address'};

  my $cisco = Cisco::IOS_XR->new(
                                 host => $address,
                                 transport => $devices->{$device}->{'method'},
                                 username => $devices->{$device}->{'username'},
                                 password => $devices->{$device}->{'password'},
                                 connection_timeout => $timeout);

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

sub getMenuResponse {

  my $cmd = shift;
  my $device = shift;

  if (!$hasJunoscript) {
    return ("Junoscript must be installed.", "");
  }

  my $result;
  my $xml;

  my $last = GRNOC::RouterProxy::Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return "Please wait $wait seconds before sending another command.";
  }
  GRNOC::RouterProxy::Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if (!defined $device) {
      return "Requested device $device is not configured. Please reload the page.";
  }

  # use JUNOSCRIPT to issue the command
  my $name = $device->{'name'};
  my $hostname = $device->{'address'};
  my $method = $device->{'method'};
  my $username = $device->{'username'};
  my $password = $device->{'password'};
  my $type = $device->{'type'};

  $username = encode("utf8", $username);
  $password = encode("utf8", $password);

  my %info = (
              access => $method,
              login => $username,
              password => $password,
              hostname => $hostname);

  my $junos = new JUNOS::Device(%info);

  if ($cmd eq "bgp") {

    $result = $junos->command("show bgp summary")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>BGP Summary For $name</td></tr></table><br />" . showBgpSummary($xml);
  }

  # show system boot-messages command
  elsif ($cmd eq "bootMessages") {

    $result = $junos->command("show system boot-messages")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>System Boot Messages For $name</td></tr></table><br />" . showSystemBootMessages($xml);
  }

  # show chassis environment command
  elsif ($cmd eq "environment") {

    $result = $junos->command("show chassis environment")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>Chassis Environment For $name</td></tr></table><br />" . showChassisEnvironment($xml);
  }

  # show system storge command
  elsif ($cmd eq "filesystem") {

    $result = $junos->command("show system storage")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>System Storage For $name</td></tr></table><br />" . showSystemStorage($xml);
  }

  # show interfaces detail
  elsif ($cmd eq "interfaces") {

    $result = $junos->command("show interfaces")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>Interfaces For $name</td></tr></table><br />" . showInterfaces($xml);
  }

  # show chassis hardware command
  elsif ($cmd eq "inventory") {

    $result = $junos->command("show chassis hardware")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>Chassis Hardware For $name</td></tr></table><br />" . showChassisHardware($xml);
  }

  # show ipv6 neighbors command
  elsif ($cmd eq "ipv6Neighbors") {

    $result = $junos->command("show ipv6 neighbors")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>IPv6 Neighbors For $name</td></tr></table><br />" . showIpv6Neighbors($xml);
  }

  # show isis adjacency command
  elsif ($cmd eq "isis") {

    $result = $junos->command("show isis adjacency")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>ISIS Adjacencies For $name</td></tr></table><br />" . showIsisAdjacency($xml);
  }

  # show msdp detail command
  elsif ($cmd eq "msdp") {

    $result = $junos->command("show msdp detail")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>MSDP Details For $name</td></tr></table><br />" . showMsdpDetail($xml);
  }

  # show multicast statistics command
  elsif ($cmd eq "multicastStatistics") {

    $result = $junos->command("show multicast statistics")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>Multicast Statistics For $name</td></tr></table><br />" . showMulticastStatistics($xml);
  }

  # show snmp statistics command
  elsif ($cmd eq "snmpStatistics") {

    $result = $junos->command("show snmp statistics")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>SNMP Statistics For $name</td></tr></table><br />" . showSnmpStatistics($xml);
  }

  # show version command
  elsif ($cmd eq "version") {

    $result = $junos->command("show version")->toString;
    $result =~ s/junos://g;
    $xml = XMLin($result, forcearray => 1);
    $result = "<table class=\"no-border\"><tr class=\"menu-title\"><td>Version For $name</td></tr></table><br />" . showVersion($xml);
  }

  return $result;
}

sub validCommand {
    my $command = shift;
    my $args    = shift;
    my $device  = shift;
    my $type    = $device->{"type"};

    # Do not allow non alphanumeric-ish chars. This prevents circumventing
    # multiple / altered commands.
    if ($command =~ /[\x00-\x1f]/ || $command =~ /\x7f/ ||
        $args =~ /[\x00-\x1f]/ || $args =~ /\x7f/) {
        return 0;
    }

    # Do not allow piping to other commands.
    if ($args =~ m/\|/) {
        return 0;
    }

    # Do not allow regexp due to IOS vulnerability.
    if ($args =~ m/regexp/i) {
        return 0;
    }

    if ($args ne "") {
        $command = $command . " " . $args;
    }

    my $validCommands   = $conf->DeviceCommands($device->{"address"});
    my $excludeCommands = $conf->DeviceExcludeCommands($device->{"address"});

    # First check to see if this command matches one of the deliberately
    # exluded ones.
    foreach my $excludeCommand (@{$excludeCommands}) {
        if ($command =~ /$excludeCommand/) {
            return 0;
        }
    }

    foreach my $validCommand (@{$validCommands}) {
        # For layer2/3, accept anything which has the prefix of a valid
        # command.
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
    for( my $i = 0; $i <= $#loc_array; $i++) {
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
