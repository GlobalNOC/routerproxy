#!/usr/bin/perl
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use CGI;
use CGI::Ajax;
use FileHandle;
use XML::Simple;
use RouterProxy;
use RouterProxyConfig;
use Commands;
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
  }
  else {
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
  }
  else {
    $hasIosXML = 1;
    Cisco::IOS_XR->import;
  }
}

use GRNOC::TL1;
use GRNOC::TL1::Device::Nortel::OME6500;
use GRNOC::TL1::Device::Nortel::HDXc;
use GRNOC::TL1::Device::Cisco::ONS15454;
use GRNOC::TL1::Device::Ciena::CoreDirector;

use Logger;
use Time::ParseDate;

use strict;

# use fast XML parser
local $ENV{'XML_SIMPLE_PREFERRED_PARSER'} = 'XML::Parser';

my $cgi = CGI->new();
my $ajax = CGI::Ajax->new(
                          'getResponse' => \&getResponse,
                          'getMenuResponse' => \&getMenuResponse,
                          'getIosMenuResponse' => \&getIosMenuResponse,
                          'getHdxcMenuResponse' => \&getHdxcMenuResponse,
                          'getOmeMenuResponse' => \&getOmeMenuResponse,
                          'getOnsMenuResponse' => \&getOnsMenuResponse,
                          'getCienaMenuResponse' => \&getCienaMenuResponse
                         );
$ajax->DEBUG(1);
$ajax->JSDEBUG(1);
my $config_path = ConfigChooser($ENV{'REQUEST_URI'}, "/etc/grnoc/routerproxy/routerproxy_mappings.xml");

unless (defined($config_path) && -e $config_path) {
   warn ("Please check mapping file. The config file for this url cannot be located\n");
   print $cgi->header();
   print $cgi->start_html();
   print "<H2>Please check mapping file. The config file for this url cannot be located</H2>";
   print $cgi->end_html();
   
   exit 1;
}

my $conf = RouterProxyConfig->New($config_path);

my $devices  = getDevices($conf);
my @routers  = parseRouters();
my @switches = parseSwitches();
my @opticals = parseOpticals();

my @all_devices = ( @routers, @switches, @opticals );

my $logfile                     = $conf->LogFile();
my $maxlines                    = $conf->MaxLines();
my $timeout                     = $conf->MaxTimeout();
my $spamSeconds                 = $conf->MaxRate();
my $global_enable_menu_commands = $conf->ShowDropdown();

my $remoteIP = $ENV{'REMOTE_ADDR'};

my $menuHTML = "";
my $iosMenu = "";
my $hdxcMenu = "";
my $omeMenu = "";
my $onsMenu = "";
my $cienaMenu = "";


$menuHTML = "<center><table class='menu-table'><tr><td><center><ul id='menu'><li><a >Hardware</a><ul><li><a onclick=menuCommand('environment')>Environment</a></li><li><a  onclick=menuCommand('filesystem')>File System</a></li><li><a  onclick=menuCommand('interfaces')>Interfaces</a></li><li><a  onclick=menuCommand('inventory')>Inventory</a></li></ul></li><li><a >Protocols</a><ul><li><a  onclick=menuCommand('bgp')>BGP</a></li><li><a  onclick=menuCommand('ipv6Neighbors')>IPV6 Neighbors</a></li><li><a  onclick=menuCommand('isis')>ISIS Adjacencies</a></li><li><a  onclick=menuCommand('msdp')>MSDP</a></li><li><a  onclick=menuCommand('multicastStatistics')>Multicast Statistics</a></li><li><a  onclick=menuCommand('snmpStatistics')>SNMP Statistics</a></li></ul></li><li><a >System</a><ul><li><a  onclick=menuCommand('bootMessages')>Boot Messages</a></li><li><a  onclick=menuCommand('version')>Version</a></li></ul></li></ul></center></td></tr></table></center>";

$iosMenu = "<center><table class='menu-table'><tr><td><center><ul id='menu'><li><a>Hardware</a><ul><li><a onclick=iosMenuCommand('interfaces')>Interfaces</a></li><li><a onclick=iosMenuCommand('inventory')>Inventory</a></li></ul></li><li><a>Protocols</a><ul><li><a onclick=iosMenuCommand('bgp')>BGP</a></li><li><a onclick=iosMenuCommand('ipv6Neighbors')>IPv6 Neighbors</a></li><li><a onclick=iosMenuCommand('isis')>ISIS</a></li><li><a onclick=iosMenuCommand('msdp')>MSDP</a></li></ul></li></ul></center></td></tr></table></center>";

$hdxcMenu = "<center><table class='menu-table'><tr><td><center><ul id='menu'><li><a >Hardware</a><ul><li><a  onclick=hdxcMenuCommand('inventory')>Inventory</a></li></ul></li><li><a >System</a><ul><li><a  onclick=hdxcMenuCommand('alarms')>Alarms</a></li><li><a  onclick=hdxcMenuCommand('circuits')>Circuits</a></li></ul></li></ul></center></td></tr></table></center>";

$omeMenu = "<center><table class='menu-table'><tr><td><center><ul id='menu'><li><a >Hardware</a><ul><li><a  onclick=omeMenuCommand('inventory')>Inventory</a></li></ul></li><li><a >System</a><ul><li><a  onclick=omeMenuCommand('alarms')>Alarms</a></li><li><a  onclick=omeMenuCommand('circuits')>Circuits</a></li></ul></li></ul></center></td></tr></table></center>";

$onsMenu = "<center><table class='menu-table'><tr><td><center><ul id='menu'><li><a >Hardware</a><ul><li><a  onclick=onsMenuCommand('inventory')>Inventory</a></li></ul></li><li><a >System</a><ul><li><a  onclick=onsMenuCommand('alarms')>Alarms</a></li><li><a  onclick=onsMenuCommand('circuits')>Circuits</a></li></ul></li></ul></center></td></tr></table></center>";

$cienaMenu = "<center><table class='menu-table'><tr><td><center><ul id='menu'><li><a >Hardware</a><ul><li><a  onclick=cienaMenuCommand('inventory')>Inventory</a></li></ul></li><li><a >System</a><ul><li><a  onclick=cienaMenuCommand('alarms')>Alarms</a></li><li><a onclick=cienaMenuCommand('circuits')>Circuits</a></li></ul></li></ul></center></td></tr></table></center>";

print $ajax->build_html($cgi, \&makeHTML);

#makeHTML2(); # Prints HTML to STDOUT

sub ConfigChooser {
  my $url = shift;
  my $map_file = shift;
 
  #if mapping file is not found
  unless (-e $map_file) {
     warn ("Mapping file is not found.\n");
     return undef;
  }

  my $config = GRNOC::Config->new( config_file => $map_file, force_array => 1 );
  
  my $entries = $config->get( '/mappings/map' );

  foreach my $entry ( @$entries ) {
     my $regexp = $entry->{'regexp'};
     if ( $url =~ /$regexp/ ) {
        return $entry->{'config_location'};
     }
  }
  return undef;
}

sub FunctionChooser {
   my $type = shift;
   my $enable_menu_commands = shift;
   my $function = "clearMenu();";

   if (defined($global_enable_menu_commands)) {
      $enable_menu_commands = $global_enable_menu_commands;
   }
      if ($type eq "junos") {
        if (!defined($enable_menu_commands) || $enable_menu_commands>0) {
           $function = "addJunOS(1);";
        }
        else {
           $function = "addJunOS(0);";
        }
           
      }
      elsif ($type eq "ios") {
        $function = "addIOS();";
      }
      elsif ($type eq "ios2") {
        $function = "addIOS2();";
      }
      elsif ($type eq "ios6509") {
        $function = "addIOS6509();";
      }
      elsif ($type eq "iosxr") {
        if (!defined($enable_menu_commands) || $enable_menu_commands>0) {
           $function = "addIOSXR(1);";
        }
        else {
           $function = "addIOSXR(0);";
        }
      }
      elsif ($type eq "hdxc") {
        if (!defined($enable_menu_commands) || $enable_menu_commands>0) {
           $function = "addHDXC(1);";
        }
        else {
           $function = "addHDXC(0);";
        }
      }
      elsif ($type eq "nx-os") {
        $function = "addNXOS();";
      }
      elsif ($type eq "ons15454") {
        if (!defined($enable_menu_commands) || $enable_menu_commands>0) {
           $function = "addONS15454(1);";
        }
        else {
           $function = "addONS15454(0);";
        }
      }
      elsif ($type eq "ome") {
        if (!defined($enable_menu_commands) || $enable_menu_commands>0) {
           $function = "addOME(1);";
        }
        else {
           $function = "addOME(0);";
        }
      }
      elsif ($type eq "ciena") {
        if (!defined($enable_menu_commands) || $enable_menu_commands>0) {
           $function = "addCiena(1);";
        }
        else {
           $function = "addCiena(0);";
        }
      }
      elsif ($type eq "force10") {
        $function = "addForce10();";
      }
      elsif ($type eq "hp") {
        $function = "addHP();";
      }elsif($type eq "brocade"){
        $function = "addBrocade();";
      }
     
      return $function;
}

sub getMenuCommands {
   my $type = shift;
   my $enable_menu_commands = shift;
   my $menu = "";

   if (defined($global_enable_menu_commands)) {
      $enable_menu_commands = $global_enable_menu_commands;
   }

   if (defined($enable_menu_commands) && $enable_menu_commands<=0) {
      return $menu;
   }
   
   if ($type eq "junos") {
      $menu = $menuHTML
   }
   elsif ($type eq "hdxc") {
      $menu = $hdxcMenu;
   }
   elsif ($type eq "ome") {
      $menu = $omeMenu;
   }
   elsif ($type eq "ons15454") {
      $menu = $onsMenu;
   }
   elsif ($type eq "ciena") {
      $menu = $cienaMenu;
   }
   elsif ($type eq "iosxr") {
      $menu = $iosMenu;
   }
  
   return $menu;
}


sub getDevice {
    my $addr = $cgi->param('address');

    # Create a copy of the device data and remove all secrets.
    my $data = $devices->{$addr};
    $data->{"commands"}    = $conf->DeviceCommands($data->{"name"});
    $data->{"enable_menu"} = $global_enable_menu_commands;
    
    delete $data->{"username"};
    delete $data->{"password"};
    delete $data->{"method"};
    delete $data->{"command_group"};
    delete $data->{"exclude_group"};

    print $cgi->header(type => "text/html");
    print encode_json($data);
}

sub getResponses {
    print $cgi->header(type => "text/plain");
    print "Response";
}

sub getError {
    print $cgi->header(type => "text/html");
    print "hello";
}

sub makeHTML2 {
    my $tt = Template->new({ ABSOLUTE => 1 });
    my $input = "/gnoc/routerproxy/templates/index.tt";

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
        return;
    }

    # Convert hash into array. Config shall be modified to use an array.
    my $device_groups = $conf->DeviceGroups();
    my $groups = [];
    foreach my $name (keys %{$device_groups}) {
        push(@{$groups}, $device_groups->{$name});
    }

    my $html = "";
    my $vars = { network_name => $conf->NetworkName(),
                 noc_mail     => $conf->NOCMail(),
                 noc_name     => $conf->NOCName(),
                 noc_site     => $conf->NOCSite(),
                 groups       => $groups
               };
    $tt->process($input, $vars, \$html);

    print $cgi->header(type => "text/html");
    print $html;
}

sub makeHTML {
  my $network = $conf->NetworkName();
  my $title   = $network . " Router Proxy";

  my $noc         = $conf->NOCName();
  my $admin       = $conf->NOCMail();
  my $nocWebsite  = $conf->NOCSite();
  my $commandHelp = $conf->NOCHelp();

  my $groups       = $conf->DeviceGroups();
  my $routerTitle  = $groups->{'3'}->{'name'};
  my $switchTitle  = $groups->{'2'}->{'name'};
  my $opticalTitle = $groups->{'1'}->{'name'};

  my $routerDisplay  = $groups->{'3'}->{'display'} ? "table" : "none";
  my $switchDisplay  = $groups->{'2'}->{'display'} ? "table" : "none";
  my $opticalDisplay = $groups->{'1'}->{'display'} ? "table" : "none";

  my $html = "
<!DOCTYPE html
  PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"
   \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en-US\" xml:lang=\"en-US\">
<head>
<title>$title</title>
<link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\" />
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
<script type=\"text/javascript\">
      //<![CDATA[

function menuCommand(cmd) {

  document.getElementById('connecting').innerHTML='Sending...';
  document.getElementById('menu-cmd').value=cmd;
  getMenuResponse(['menu-cmd', 'device'], ['response', 'connecting']);
  document.getElementById('response').style.display='block';
}

function iosMenuCommand(cmd) {

  document.getElementById('connecting').innerHTML='Sending...';
  document.getElementById('menu-cmd').value=cmd;
  getIosMenuResponse(['menu-cmd', 'device'], ['response', 'connecting']);
  document.getElementById('response').style.display='block';
}

function hdxcMenuCommand(cmd) {

  document.getElementById('connecting').innerHTML='Sending...';
  document.getElementById('menu-cmd').value=cmd;
  getHdxcMenuResponse(['menu-cmd', 'device'], ['response', 'connecting']);
  document.getElementById('response').style.display='block';
}

function omeMenuCommand(cmd) {

  document.getElementById('connecting').innerHTML='Sending...';
  document.getElementById('menu-cmd').value=cmd;
  getOmeMenuResponse(['menu-cmd', 'device'], ['response', 'connecting']);
  document.getElementById('response').style.display='block';
}

function onsMenuCommand(cmd) {

  document.getElementById('connecting').innerHTML='Sending...';
  document.getElementById('menu-cmd').value=cmd;
  getOnsMenuResponse(['menu-cmd', 'device'], ['response', 'connecting']);
  document.getElementById('response').style.display='block';
}

function cienaMenuCommand(cmd) {

  document.getElementById('connecting').innerHTML='Sending...';
  document.getElementById('menu-cmd').value=cmd;
  getCienaMenuResponse(['menu-cmd', 'device'], ['response', 'connecting']);
  document.getElementById('response').style.display='block';
}

function clearMenu() {
   document.getElementById('menu-commands').innerHTML='';
}

function addJunOS(menu) {

  removeOptions();
  var myArray = new Array();";

  my $commands = $conf->CommandsInGroup('junos-commands');
  my $i = 0;
  foreach my $command (@$commands) {
    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
  var menuCommandHTML = \"\";
  if (menu==1) { menuCommandHTML = \"$menuHTML\"; }
  document.getElementById('menu-commands').innerHTML=menuCommandHTML;
}

function addIOS() {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('ios-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
document.getElementById('menu-commands').innerHTML='';
}

function addNXOS() {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('nx-os-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }

  $html .= "addOptions(myArray);
document.getElementById('menu-commands').innerHTML='';
}

function addIOS2() {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('ios2-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
document.getElementById('menu-commands').innerHTML='';
}

function addBrocade(){
  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('brocade-commands');
  $i = 0;
  foreach my $command (@$commands) {

      $html .= "myArray[$i] = \"$command\";\n";
      $i++;
  }
  $html .= "addOptions(myArray);                                                                                                                                                                                                                                                       
document.getElementById('menu-commands').innerHTML='';        
}

function addIOS6509() {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('ios6509-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
document.getElementById('menu-commands').innerHTML='';
}

function addIOSXR(menu) {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('iosxr-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
var menuCommandHTML = \"\";
  if (menu==1) { menuCommandHTML = \"$iosMenu\"; }
document.getElementById('menu-commands').innerHTML=menuCommandHTML;
}

function addHDXC(menu) {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('hdxc-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
var menuCommandHTML = \"\";
  if (menu==1) { menuCommandHTML = \"$hdxcMenu\"; }
document.getElementById('menu-commands').innerHTML=menuCommandHTML;
}

function addONS15454(menu) {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('ons15454-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
var menuCommandHTML = \"\";
  if (menu==1) { menuCommandHTML = \"$onsMenu\"; }
document.getElementById('menu-commands').innerHTML=menuCommandHTML;
}

function addOME(menu) {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('ome-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
var menuCommandHTML = \"\";
  if (menu==1) { menuCommandHTML = \"$omeMenu\"; }
document.getElementById('menu-commands').innerHTML=menuCommandHTML;
}

function addCiena(menu) {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('ciena-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
var menuCommandHTML = \"\";
  if (menu==1) { menuCommandHTML = \"$cienaMenu\"; }
document.getElementById('menu-commands').innerHTML=menuCommandHTML;
}

function addForce10() {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('force10-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
document.getElementById('menu-commands').innerHTML='';
}

function addHP() {

  removeOptions();
  var myArray = new Array();";

  $commands = $conf->CommandsInGroup('hp-commands');
  $i = 0;
  foreach my $command (@$commands) {

    $html .= "myArray[$i] = \"$command\";\n";
    $i++;
  }
  $html .= "addOptions(myArray);
document.getElementById('menu-commands').innerHTML='';
}

function addOptions(vals) {

  var object = document.getElementById(\"cmd\");
  for (var i = 0; i < vals.length; i++) {
    object.options[object.options.length] = new Option(vals[i], vals[i], false, false);
  }
}

function removeOptions() {

  var object = document.getElementById(\"cmd\");
  for (var i = object.options.length - 1; i >= 0; i--) {
    object.options[i] = null;
  }
  object.selectedIndex = -1;
}

function toggle(id) {

  var object = document.getElementById(id);
  var currentDisplay = object.style.display;

  if (currentDisplay == 'none') {

    object.style.display = 'table';
  }

  else {

    object.style.display = 'none';
  }
}

//]]>
</script>
</head>
<body>
<div class=\"logo\">$network Router Proxy</div>";

  if ($noc ne "") {

    $html .= "
<center>
  <h2>A service of the <a href=\"$nocWebsite\">$noc</a></h2>
</center>";
  }
  else {

    $html .= "<br />";
  }

  if (@routers > 0) {

      $html .= "<div class=\"devices\">
    <table class=\"title\">
    <tr class=\"menu-title\" onclick=\"toggle('router-menu');\"><td colspan=\"3\">$routerTitle</td></tr>
    </table>
    <table id='router-menu' style='display: $routerDisplay'>";

      my $devicesHTML = "";
      my $i = 0;
      
    foreach my $device (@routers) {

      if ($i == 0) {
        $devicesHTML .= "<tr class=\"primary\">";
      }

      my $name = $device->{'name'};
      my $address = $device->{'address'};
      my $city = $device->{'city'};
      my $state = $device->{'state'};
      my $type = $device->{'type'};

      my $location_data = _parseLocationData( city => $city, state => $state);

      my $function = FunctionChooser($type, $device->{'enable-menu-commands'});

      $devicesHTML .= "<td><input name=\"device\" id=\"device\" type=\"radio\" value=\"$address\" onClick=\"$function\" />$name $location_data</td>";
      if ($i == 2) {
        $devicesHTML .= "</tr>";
        $i = -1;
      }
      $i++;
    }
    if ($i == 1) {
      $devicesHTML .= "<td></td><td></td></tr>";
    }
    elsif ($i == 2) {
      $devicesHTML .= "<td></td></tr>";
    }
      $html .= $devicesHTML;
      $html .= "
    </table>
  </div>
  <br />";
  }

  if (@switches > 0) {

    $html .= "<div class=\"devices\">

    <table class=\"title\">
    <tr class=\"menu-title\" onclick=\"toggle('switch-menu');\"><td colspan=\"3\">$switchTitle</td></tr>
    </table>
    <table id='switch-menu' style='display: $switchDisplay'>";

    my $devicesHTML = "";
    my $i = 0;

    foreach my $device (@switches) {

      if ($i == 0) {
        $devicesHTML .= "<tr class=\"primary\">";
      }

      my $name = $device->{'name'};
      my $address = $device->{'address'};
      my $city = $device->{'city'};
      my $state = $device->{'state'};
      my $type = $device->{'type'};
      
      my $location_data = _parseLocationData( city => $city, state => $state);

      my $function = FunctionChooser($type, $device->{'enable-menu-commands'});

      $devicesHTML .= "<td><input name=\"device\" id=\"device\" type=\"radio\" value=\"$address\" onClick=\"$function\" />$name $location_data</td>";
      if ($i == 2) {
        $devicesHTML .= "</tr>";
        $i = -1;
      }
      $i++;
    }
    if ($i == 1) {
      $devicesHTML .= "<td></td><td></td></tr>";
    }
    elsif ($i == 2) {
      $devicesHTML .= "<td></td></tr>";
    }
    $html .= $devicesHTML;
    $html .= "
    </table>
  </div>
  <br />";
  }

  if (@opticals > 0) {

    $html .= "<div class=\"devices\">

    <table class=\"title\">
    <tr class=\"menu-title\" onclick=\"toggle('optical-menu');\"><td colspan=\"3\">$opticalTitle</td></tr>
    </table>
    <table id='optical-menu' style='display: $opticalDisplay'>";

    my $devicesHTML = "";
    my $i = 0;

    foreach my $device (@opticals) {

      if ($i == 0) {
        $devicesHTML .= "<tr class=\"primary\">";
      }

      my $name = $device->{'name'};
      my $address = $device->{'address'};
      my $city = $device->{'city'};
      my $state = $device->{'state'};
      my $type = $device->{'type'};

      my $location_data = _parseLocationData( city => $city, state => $state);
      my $function = FunctionChooser($type, $device->{'enable-menu-commands'});

      $devicesHTML .= "<td><input name=\"device\" id=\"device\" type=\"radio\" value=\"$address\" onClick=\"$function\" />$name $location_data</td>";
      if ($i == 2) {
        $devicesHTML .= "</tr>";
        $i = -1;
      }
      $i++;
    }
    if ($i == 1) {
      $devicesHTML .= "<td></td><td></td></tr>";
    }
    elsif ($i == 2) {
      $devicesHTML .= "<td></td></tr>";
    }
    $html .= $devicesHTML;
    $html .= "
    </table>
  </div>
  <br />";
  }

  $html .= "
  <div class=\"menu-commands\" id=\"menu-commands\">";

  my $type1 = $all_devices[0]->{'type'};
  my $menu1 = $all_devices[0]->{'enable-menu-commands'};
  $html .= getMenuCommands($type1, $menu1);

  $html .= "</div>

  <br />
  <center><h4>";

  $html .= $commandHelp;
  $html .= "</h4></center>";
  $html .= "<div class=\"query\" id=\"query\">
    Command: <select class=\"c\" name=\"cmd\" id=\"cmd\">";

  # grab all the commands
  my $type = "";
  if ($all_devices[0]->{'type'} eq "ios") {
    $type = "ios-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "ios6509") {
    $type = "ios6509-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "ios2") {
    $type = "ios2-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "junos") {
    $type = "junos-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "iosxr") {
    $type = "iosxr-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "nx-os") {
    $type = "nx-os-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "hdxc") {
    $type = "hdxc-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "ons15454") {
    $type = "ons15454-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "ome") {
    $type = "ome-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "ciena") {
    $type = "ciena-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "force10") {
    $type = "force10-commands";
  }
  elsif ($all_devices[0]->{'type'} eq "hp") {
      $type = "hp-commands";
  }elsif ($all_devices[0]->{'type'} eq "brocade"){
      $type = "brocade-commands";
  }
  $commands = $conf->CommandsInGroup($type);
  foreach my $command (@$commands) {
    $html .= "<option>$command</option>"
  }
  $html .= "
        </select>
        <input class=\"q\" type=\"text\" name=\"args\" id=\"args\" onKeyUp=\"if (event.keyCode == 13) { document.getElementById('connecting').innerHTML='Sending...';getResponse(['cmd', 'args', 'device'], ['response', 'connecting']);document.getElementById('response').style.display='block'; }\"/> <input class=\"s\" type=\"submit\" value=\"Submit\" onclick=\"document.getElementById('connecting').innerHTML='Sending...';getResponse(['cmd', 'args', 'device'], ['response', 'connecting']);document.getElementById('response').style.display='block';\" />
  </div>
  <div class=\"connecting\" id=\"connecting\"></div>
  <br />
  <br />
  <div class=\"response\" id=\"response\"></div>

<center>
  <hr width=\"50%\" />
  <h4>Developed by Global Research NOC Systems Engineering<br />
  Copyright 2010, The Trustees of Indiana University</h4>
</center>
</body>

<input type=\"hidden\" id=\"menu-cmd\"></input>

<script type=\"text/javascript\">
  document.getElementById('response').style.display='none';
</script>
</html>";
  
  return $html;
}

sub getCienaMenuResponse {

  my $cmd = shift;
  my $device = shift;

  my @rows;
  my $result;

  my $last = Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return ("Please wait $wait seconds before sending another command.", "");
  }
  Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return ("Requested device is not configured.  Please reload the page.", "" );
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

  return ($result, "");
}

sub getOnsMenuResponse {

  my $cmd = shift;
  my $device = shift;

  my @rows;
  my $result;

  my $last = Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return ("Please wait $wait seconds before sending another command.", "");
  }
  Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return ("Requested device is not configured.  Please reload the page.", "" );
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

  # facilities cmd
  #elsif ($cmd eq "facilities") {

  #@rows = $tl1->getFacilities();
  #$result = retrFac(@rows);
  #}

  # inventory cmd
  elsif ($cmd eq "inventory") {

    @rows = $tl1->get_inventory();
    $result = retrInv(@rows);
  }

  # ip addresses cmd
  #elsif ($cmd eq "ipAddresses") {

  #@rows = $tl1->getIPInfo();
  #$result = retrNeGen(@rows);
  #}

  return ($result, "");
}

sub getOmeMenuResponse {

  my $cmd = shift;
  my $device = shift;

  my @rows;
  my $result;

  my $last = Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return ("Please wait $wait seconds before sending another command.", "");
  }
  Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return ("Requested device is not configured.  Please reload the page.", "" );
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

  # ip addresses cmd
  #elsif ($cmd eq "ipAddresses") {

  #@rows = $tl1->getIPInfo();
  #$result = retrIp2(@rows);
  # ons15454$result = retrNeGen(@rows);
  #}

  return ($result, "");
}

sub getHdxcMenuResponse {

  my $cmd = shift;
  my $device = shift;

  my @rows;
  my $result;

  my $last = Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return ("Please wait $wait seconds before sending another command.", "");
  }
  Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return ("Requested device is not configured.  Please reload the page.", "" );
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

  # ip addresses cmd
  #elsif ($cmd eq "ipAddresses") {

  #@rows = $tl1->getIPInfo();

  #if ($type eq "hdxc") {
  #   $result = retrIp(@rows);
  #}
  #elsif ($type eq "ome") {
  #    $result = retrIp2(@rows);
  #}
  #else {
  #    $result = retrNeGen(@rows);
  #}
  #}

  return ($result, "");
}

sub getIosMenuResponse {

  my $cmd = shift;
  my $device = shift;

  if (!$hasIosXML) {

    return ("IOS XR XML must be installed.", "");
  }

  my $result;

  my $last = Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return ("Please wait $wait seconds before sending another command.", "");
  }
  Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return ("Requested device is not configured.  Please reload the page.", "" );
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

  return ($result, "");
}

sub getMenuResponse {

  my $cmd = shift;
  my $device = shift;

  if (!$hasJunoscript) {

    return ("Junoscript must be installed.", "");
  }

  my $result;
  my $xml;

  my $last = Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return ("Please wait $wait seconds before sending another command.", "");
  }
  Logger::addEntry($logfile, $remoteIP, $device, $cmd);

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return ("Requested device is not configured.  Please reload the page.", "" );
  }

  # use JUNOSCRIPT to issue the command
  my $name = $devices->{$device}->{'name'};
  my $hostname = $devices->{$device}->{'address'};
  my $method = $devices->{$device}->{'method'};
  my $username = $devices->{$device}->{'username'};
  my $password = $devices->{$device}->{'password'};
  my $type = $devices->{$device}->{'type'};

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

  return ($result, "");
}

sub getResponse {

  my $cmd = shift;
  my $args = shift;

  # I have no idea why I have to do this extra shift...
  shift;

  my $device = shift;

  my $last = Logger::getLastTime($logfile);
  my $now = time();
  my $diff = $now - $last;
  if ($diff < $spamSeconds) {
    my $wait = $spamSeconds - $diff;
    return ("Please wait $wait seconds before sending another command.", "");
  }

  # make sure the device exists in the config
  if ( !defined( $devices->{$device} ) ) {

      return ("Requested device is not configured.  Please reload the page.", "" );
  }

  Logger::addEntry($logfile, $remoteIP, $device, $cmd . " " . $args);

  if (!validCommand($cmd, $args, $device)) {

    return ("Disabled Command.", "");
  }

  if ($args ne "") {
    $cmd = $cmd . " " . $args;
  }

  my $name = $devices->{$device}->{'name'};
  my $hostname = $devices->{$device}->{'address'};
  my $method = $devices->{$device}->{'method'};
  my $username = $devices->{$device}->{'username'};
  my $password = $devices->{$device}->{'password'};
  my $type = $devices->{$device}->{'type'};
  my $port = $devices->{$device}->{'port'};

  # fix encoding
  Encode::from_to($username, 'utf8', 'iso-8859-1');
  Encode::from_to($password, 'utf8', 'iso-8859-1');

  my $result = "
<table class=\"no-border\">
<tr class=\"menu-title\"><td>Response From $name</td></tr>
<tr class=\"primary\">
<td>
<pre>";

  my $proxy = RouterProxy->new(
                               hostname => $hostname,
                               port => $port,
                               username => $username,
                               password => $password,
                               method => $method,
                               type => $type,
                               maxlines => $maxlines,
                               config_path => $config_path,
                               timeout => $timeout
                              );

  my $output = $proxy->command($cmd);

  # end the timer if the command was successful
  alarm(0);

  $result .= $output;
  $result .= "
</pre>
</td>
</tr>
</table>
";

  return ($result, "");
}

sub getDevices {
    my $conf = shift;

    my $results = {};
    my $devices = $conf->Devices();

    foreach my $name (keys %{$devices}) {
        my $addr = $devices->{$name}->{'address'};
        $results->{$addr} = $devices->{$name};
    }
    return $results;
}

sub parseRouters {

    my @result;
    my $i = 0;
    
    my @hostnames = keys( %$devices );
    
    foreach my $hostname ( @hostnames ) {
	
	my $device = $devices->{$hostname};
	my $layer = $device->{'device_group'};
	
	if ($layer == 3) {
	    
	    $result[$i++] = $device;
	}
    }
    
    return sort { $a->{'name'} cmp $b->{'name'} } @result;
}

sub parseSwitches {

    my @result;
    my $i = 0;

    my @hostnames = keys( %$devices );

    foreach my $hostname ( @hostnames ) {

        my $device = $devices->{$hostname};
        my $layer = $device->{'device_group'};

        if ($layer == 2) {

            $result[$i++] = $device;
	}
    }

    return sort { $a->{'name'} cmp $b->{'name'} } @result;
}

sub parseOpticals {

    my @result;
    my $i = 0;

    my @hostnames = keys( %$devices );

    foreach my $hostname ( @hostnames ) {

        my $device = $devices->{$hostname};
        my $layer = $device->{'device_group'};

        if ($layer == 1) {

            $result[$i++] = $device;
	}
    }

    return sort { $a->{'name'} cmp $b->{'name'} } @result;
}

sub validCommand {

  my $command = shift;
  my $args = shift;
  my $device = shift;
  my $os = "";

  # dont allow non alphanumeric-ish chars (to prevent circumventing multiple/altered commands)
  if ($command =~ /[\x00-\x1f]/ || $command =~ /\x7f/ ||
      $args =~ /[\x00-\x1f]/ || $args =~ /\x7f/) {
      return 0;
  }

  # dont allow piping to other commands
  if ($args =~ m/\|/) {
   
    return 0;
  }

  # dont allow regexp due to IOS vulnerability
  if ($args =~ m/regexp/i) {
   
    return 0;
  }

  if ($args ne "") {
    $command = $command . " " . $args;
  }

  my $type = $devices->{$device}->{'type'};
  if ($type eq "junos") {

    $os = "junos-commands";
  }

  elsif ($type eq "ios") {

    $os = "ios-commands";
  }

  elsif ($type eq "ios6509") {

    $os = "ios6509-commands";
  }
  elsif ($type eq "ios2") {

    $os = "ios2-commands";
  }
  elsif ($type eq "iosxr") {

    $os = "iosxr-commands";
  }

  elsif ($type eq "nx-os") {

    $os = "nx-os-commands";
  }

  elsif ($type eq "ome") {

    $os = "ome-commands";
  }

  elsif ($type eq "ons15454") {

    $os = "ons15454-commands";
  }

  elsif ($type eq "hdxc") {

    $os = "hdxc-commands";
  }

  elsif ($type eq "ciena") {

    $os = "ciena-commands";
  }

  elsif ($type eq "force10") {

    $os = "force10-commands";
  }

  elsif ($type eq "hp") {

    $os = "hp-commands";
}elsif($type eq "brocade"){
    $os = "brocade-commands";
}
  
  my $validCommands   = $conf->CommandsInGroup($os);
  my $excludeCommands = $conf->CommandsExcludedFromGroup($os);

  # first check to see if this command matches one of the deliberately exluded ones
  foreach my $excludeCommand (@$excludeCommands) {

    if ($command =~ /$excludeCommand/) {
      return 0;
    }

  }

  foreach my $validCommand (@$validCommands) {

    # for layer2/3, accept anything which has the prefix of a valid command
    if ($type eq "ciena" || $type eq "hdxc" || $type eq "ons15454" || $type eq "ome") {

      return 1 if ($command eq $validCommand);
    }
    else {
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
