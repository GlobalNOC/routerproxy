package GRNOC::RouterProxy::Commands;

use XML::Simple;
use Data::Dumper;

our $i;
our $j;
our $k;

use strict;

sub ipv6Neighbors {

  my $xml = shift;
  my $result;

  $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>IPv6 Address</td><td>Age</td><td>MAC Address</td><td>State</td><td>Interface</td></tr>";

  my $output = $xml->{'CLI'}->[0]->{'Exec'}->[0];
  my @lines = split('\n', $output);

  my $primary = 1;
  my $class;

  foreach my $line (@lines) {

    if ($line =~ /^([^\s]*)\s*([^\s]*)\s*([^\s]*)\s*([^\s]*)\s*([^\n]*)$/) {

      my $address = $1;
      my $age = $2;
      my $mac = $3;
      my $state = $4;
      my $intf = $5;

      next if ($address eq "IPv6" || $address eq "[Mcast");

      if ($primary) {
        $class = "primary";
      }
      else {
        $class = "secondary";
      }
      $primary = !$primary;

      $result .= "<tr class=\"$class\"><td>$address</td><td>$age</td><td>$mac</td><td>$state</td><td>$intf</td></tr>";
    }
  }

  $result .= "</table>";
  return $result;
}

sub inventory {

  my $xml = shift;
  my $result;

  $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Name</td><td>Description</td><td>PID</td><td>VID</td><td>Serial</td></tr>";

  my $output = $xml->{'CLI'}->[0]->{'Exec'}->[0];
  my @lines = split('\n', $output);

  my $primary = 1;
  my $class;
  for (my $i = 0; $i < @lines; $i++) {

    my $line = $lines[$i];

    if ($line =~ /^NAME: "([^"]*)".*DESCR: "([^"]*)"$/) {

      my $name = $1;
      my $desc = $2;

      $line = $lines[++$i];
      $line =~ /^PID: ([^,]*), VID: ([^,]*), SN: ([^\n]*)$/;
      my $pid = $1;
      my $vid = $2;
      my $serial = $3;

      if ($primary) {
        $class = "primary";
      }
      else {
        $class = "secondary";
      }
      $primary = !$primary;

      $result .= "<tr class=\"$class\"><td>$name</td><td>$desc</td><td>$pid</td><td>$vid</td><td>$serial</td></tr>";
    }
  }

  $result .= "</table>";
  return $result;
}

sub msdp {

  my $xml = shift;

  my $result;

  $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Peer Address</td><td>Source</td><td>Description</td><td>Enabled</td></tr>";

  my $peers = $xml->{'Get'}->[0]->{'Configuration'}->[0]->{'MSDP'}->[0]->{'PeerTable'}->[0]->{'Peer'};

  my $primary = 1;

  foreach my $peer (@$peers) {

    my $enabled = $peer->{'Enable'}->[0];

    if ($enabled eq "true") {
      $enabled = "Yes";
    }
    else {
      $enabled = "No";
    }

    my $addr = $peer->{'Naming'}->[0]->{'PeerAddress'}->[0];
    my $source = $peer->{'ConnectSource'}->[0];
    my $desc = $peer->{'Description'}->[0];

    if ($primary) {

      $result .= "<TR class=\"primary\"><TD>$addr</TD><TD>$source</TD><TD>$desc</TD><TD>$enabled</TD></TR>";
    }
    else {

      $result .= "<TR class=\"secondary\"><TD>$addr</TD><TD>$source</TD><TD>$desc</TD><TD>$enabled</TD></TR>";
    }

    $primary = !$primary;
  }

  return $result;
}

sub isis {

  my $xml = shift;
  my $interfaces = $xml->{'Get'}->[0]->{'Configuration'}->[0]->{'ISIS'}->[0]->{'InstanceTable'}->[0]->{'Instance'}->[0]->{'InterfaceTable'}->[0]->{'Interface'};

  my $result;

  $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Interface</td><td>Running</td>
          <td>State</td>
          <td>Circuit Type</td></tr>";

  my $primary = 1;
  foreach my $interface (@$interfaces) {

    my $name = $interface->{'Naming'}->[0]->{'Name'}->[0];
    my $running = $interface->{'Running'}->[0];
    my $state = $interface->{'State'}->[0];
    my $type = $interface->{'CircuitType'}->[0];

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {

      $class = "secondary";
    }
    $primary = !$primary;

    $result .= "<tr class=\"$class\"><td>$name</td><td>$running</td><td>$state</td><td>$type</td></tr>";
  }

  $result .= "</table>";

  return $result;
}

sub bgp {

  my $bgp_data = shift;
  my $oper = shift;
  my $result;

  $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>IP Address</td><td>Remote AS</td><td>Local AS</td>
          <td>Description</td><td>Uptime</td><td>Admin Up</td></tr>";

  my $primary = 1;

  foreach my $entry ($bgp_data->get_keys()) {

    my $entries = $oper->BGP->DefaultVRF->NeighborTable->Neighbor($entry)->get_entries();
    my $xml = XMLin($entries->to_string(), forcearray => 1);
    my $neighbor = $xml->{'Get'}->[0]->{'Operational'}->[0]->{'BGP'}->[0]->{'DefaultVRF'}->[0]->{'NeighborTable'}->[0]->{'Neighbor'}->[0];

    # get ipv6 or ipv6 address
    my $address = $neighbor->{'ConnectionRemoteAddress'}->[0]->{'IPV4Address'};

    if (defined($address)) {

      $address = $address->[0];
    }

    else {

      $address = $neighbor->{'ConnectionRemoteAddress'}->[0]->{'IPV6Address'}->[0];
    }

    my $admin_up = $neighbor->{'IsAdministrativelyShutDown'}->[0];

    $admin_up = "No" if ($admin_up eq "true");
    $admin_up = "Yes" if ($admin_up ne "No");

    my $description = $neighbor->{'Description'}->[0];
    my $remote_as = $neighbor->{'RemoteAS'}->[0];
    my $local_as = $neighbor->{'LocalAS'}->[0];
    my $uptime_seconds = $neighbor->{'TimeSinceConnectionLastDropped'}->[0];

    if ($primary) {

      $result .= "<TR class=\"primary\"><TD>$address</TD><TD>$remote_as</TD><TD>$local_as</TD><TD>$description</TD>
                      <TD>$uptime_seconds secs</TD><TD>$admin_up</TD></TR>";
    }

    else {

      $result .= "<TR class=\"secondary\"><TD>$address</TD><TD>$remote_as</TD><TD>$local_as</TD><TD>$description</TD>
                      <TD>$uptime_seconds secs</TD><TD>$admin_up</TD></TR>";
    }

    $primary = !$primary;
  }

  $result .= "</table>";

  return $result;
}

sub ips {

  my $str = shift;
  my $xml = XMLin($str, forcearray => 1);

  print qq {
        <P>
        <TABLE class="info" cellspacing="0" cellpadding="4" width="900">
        <TR class="title"><TD class="title">Interface</TD><TD class="title">IP Address</TD>
          <TD class="title">Netmask</TD></TR>
    };

  my $ifs = $xml->{'Get'}->[0]->{'Configuration'}->[0]->{'InterfaceConfigurationTable'}->[0]->{'InterfaceConfiguration'};
  my $primary = 1;

  # skip the first
  for ($i = 1; $i < @$ifs; $i++) {

    my $name = $ifs->[$i]->{'Naming'}->[0]->{'Name'}->[0];
    my $ip = $ifs->[$i]->{'IPV4Network'}->[0]->{'Addresses'}->[0]->{'Primary'}->[0]->{'IPAddress'}->[0];
    my $netmask = $ifs->[$i]->{'IPV4Network'}->[0]->{'Addresses'}->[0]->{'Primary'}->[0]->{'Mask'}->[0];

    if ($primary) {

      print qq {
                  <TR><TD class="primary">$name</TD><TD class="primary">$ip</TD><TD class="primary">$netmask</TD></TR>
        };
    }

    else {

      print qq {
                  <TR><TD>$name</TD><TD>$ip</TD><TD>$netmask</TD></TR>

      };
    }

    $primary = !$primary;
  }

  print qq {</TABLE></P>};
}

sub interfaces {

  my $xml = shift;

  my $result = "
        <table class=\"no-border\">
        <TR class=\"title\"><TD>Interface</TD><TD>Active</TD>
          <TD>IP Address</TD><TD>Netmask</TD><TD>MTU</TD><TD>Description</TD></TR>";

  my $interfaces = $xml->{'Get'}->[0]->{'Configuration'}->[0]->{'InterfaceConfigurationTable'}->[0]->{'InterfaceConfiguration'};

  my $primary = 1;

  foreach my $interface (@$interfaces) {

    my $name = $interface->{'Naming'}->[0]->{'Name'}->[0];
    my $ip = $interface->{'IPV4Network'}->[0]->{'Addresses'}->[0]->{'Primary'}->[0]->{'IPAddress'}->[0];
    my $netmask = $interface->{'IPV4Network'}->[0]->{'Addresses'}->[0]->{'Primary'}->[0]->{'Mask'}->[0];
    my $mtu = $interface->{'MTUConfiguration'}->[0]->{'MTU'}->[0]->{'MTU'}->[0];
    my $active = $interface->{'Naming'}->[0]->{'Active'}->[0];
    my $desc = $interface->{'Description'}->[0];

    if ($active eq "act") {
      $active = "Yes";
    }
    else {
      $active = "No";
    }

    if ($primary) {

      $result .= "<TR class=\"primary\"><TD>$name</TD><TD>$active</TD>
                      <TD>$ip</TD><TD>$netmask</TD><TD>$mtu</TD><TD>$desc</TD></TR>";
    }

    else {

      $result .= "<TR class=\"secondary\"><TD>$name</TD><TD>$active</TD>
                      <TD>$ip</TD><TD>$netmask</TD><TD>$mtu</TD><TD>$desc</TD></TR>";
    }

    $primary = !$primary;
  }

  $result .= "</table>";
  return $result;
}

sub retrAlmAll3 {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
        <tr class=\"title\"><td>ID</td><td>Type</td>
          <td>Severity</td><td>Condition Type</td><td>Service Affective</td>
          <td>Date</td><td>Time</td><td>Location</td><td>Direction</td>
          <td>Description</td></tr>";

  my $primary = 1;

  foreach my $alarm (@result) {

    my $id = $alarm->{'aid'};
    my $type = $alarm->{'aid_type'};
    my $severity = $alarm->{'severity'};
    my $condType = $alarm->{'cond_type'};
    my $servAffect = $alarm->{'serv_affect'};
    my $date = $alarm->{'date'};
    my $time = $alarm->{'time'};
    my $loc = $alarm->{'location'};
    my $dir = $alarm->{'direction'};
    my $desc = $alarm->{'description'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $answer .= "
                  <tr class=\"$class\"><td>$id</td><td>$type</td><td>$severity</td>
                      <td>$condType</td><td>$servAffect</td><td>$date</td><td>$time</td>
                      <td>$loc</td><td>$dir</td><td>$desc</td></tr>";
  }
  $answer .= "</table>";

  return $answer;
}

sub retrAlmAll2 {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Equipment</td><td>Type</td>
          <td>Notification Code</td><td>Condition Type</td><td>Description</td><td>Service Affective</td>
          <td>Location</td><td>Direction</td><td>Alarm ID</td><td>Cause ID</td>
          <td>Doc. Index</td><td>Date</td></tr>";

  my $primary = 1;

  foreach my $alarm (@result) {

    my $equipmentID = $alarm->{'aid'};
    my $alarmType = $alarm->{'aid_type'};
    my $notCode = $alarm->{'not_code'};
    my $condType = $alarm->{'cond_type'};
    my $desc = $alarm->{'description'};
    my $servAffect = $alarm->{'serv_affect'};
    my $loc = $alarm->{'location'};
    my $dir = $alarm->{'direction'};
    my $id = $alarm->{'id'};
    my $probCause = $alarm->{'prob_cause'};
    my $docIndex = $alarm->{'doc_index'};
    my $month = $alarm->{'month'};
    my $day = $alarm->{'day'};
    my $time = $alarm->{'time'};
    my $year = $alarm->{'year'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $answer .= "
                  <tr class=\"$class\"><td>$equipmentID</td><td>$alarmType</td>
                      <td>$notCode</td><td>$condType</td><td>$desc</td><td>$servAffect</td>
                      <td>$loc</td><td>$dir</td><td>$id</td>
                      <td>$probCause</td><td>$docIndex</td><td>$month.$day.$year $time</td></tr>";
  }
  $answer .= "</table>";

  return $answer;
}

sub retrAlmAll {

  my @result = @_;
  my $answer;

  # determine if its ONS 15454
  if (@result > 0 && $result[$i]->{'probCause'} eq "") {

    $answer = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Equipment</td><td>Type</td>
          <td>Notification Code</td><td>Condition Type</td><td>Service Affective</td>
          <td>Description</td><td>Date</td></tr>";

    my $primary = 1;

    foreach my $alarm (@result) {

      my $equipmentID = $alarm->{'aid'};
      my $alarmType = $alarm->{'aid_type'};
      my $notCode = $alarm->{'not_code'};
      my $condType = $alarm->{'cond_type'};
      my $servAffect = $alarm->{'serv_affect'};
      my $desc = $alarm->{'description'};
      my $month = $alarm->{'month'};
      my $day = $alarm->{'day'};
      my $time = $alarm->{'time'};

      my $class;
      if ($primary) {

        $class = "primary";
      }
      else {
        $class = "secondary";
      }

      $answer .= "
                  <tr class=\"$class\"><td>$equipmentID</td><td>$alarmType</td>
                      <td>$notCode</td><td>$condType</td><td>$servAffect</td>
                      <td>$desc</td><td>$month.$day $time</td></tr>";

      $primary = !$primary;
    }
  }

  # HDXc
  else {

    $answer = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Equipment</td><td>Type</td>
          <td>Notification Code</td><td>Condition Type</td><td>Service Affective</td>
          <td>Location</td><td>Direction</td><td>Date</td><td>Description</td></tr>";

    my $primary = 1;

    foreach my $alarm (@result) {

      my $equipmentID = $alarm->{'aid'};
      my $alarmType = $alarm->{'aid_type'};
      my $notCode = $alarm->{'not_code'};
      my $condType = $alarm->{'cond_type'};
      my $servAffect = $alarm->{'serv_affect'};
      my $loc = $alarm->{'location'};
      my $dir = $alarm->{'direction'};
      my $month = $alarm->{'month'};
      my $day = $alarm->{'day'};
      my $time = $alarm->{'time'};
      my $year = $alarm->{'year'};
      my $description = $alarm->{'description'};

      my $class;
      if ($primary) {

        $class = "primary";
      }
      else {
        $class = "secondary";
      }
      $primary = !$primary;

      $answer .= "
                  <tr class=\"$class\"><td>$equipmentID</td><td>$alarmType</td>
                      <td>$notCode</td><td>$condType</td><td>$servAffect</td>
                      <td>$loc</td><td>$dir</td><td>$month.$day.$year $time</td><td>$description</tr>";
    }
  }

  $answer .= "</table>";
  return $answer;
}

sub retrCrs2 {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Name</td><td>From</td><td>To</td><td>From Type</td><td>To Type</td>
          <td>Alias</td><td>Rate</td><td>Primary State</td></tr>";

  my $primary = 1;
  foreach my $circuit (@result) {

    my $from = $circuit->{'from_aid'};
    my $name = $circuit->{'name'};
    my $to = $circuit->{'to_aid'};
    my $fromType = $circuit->{'from_type'};
    my $toType = $circuit->{'to_type'};
    my $alias = $circuit->{'alias'};
    my $size = $circuit->{'rate'};
    my $priority = $circuit->{'priority'};
    my $primaryState = $circuit->{'state'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }

    $answer .= "<tr class=\"$class\"><td>$name</td><td>$from</td><td>$to</td><td>$fromType</td>
                      <td>$toType</td><td>$alias</td><td>$size</td><td>$primaryState</td></tr>";

    $primary = !$primary;
  }
  $answer .= "</table>";
  return $answer;
}

sub retrCrs {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Source</td><td>Destination</td>
          <td>Type</td><td>Circuit ID</td>
          <td>Primary State</td></tr>";

  my $primary = 1;
  foreach my $circuit (@result) {

    my $src = $circuit->{'from_aid'};
    my $dst = $circuit->{'to_aid'};
    my $crstype = $circuit->{'type'};
    my $id = $circuit->{'description'};
    my $prime = $circuit->{'state'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }

    $answer .= "<tr class=\"$class\"><td>$src</td><td>$dst</td>
                      <td>$crstype</td><td>$id</td><td>$prime</td></tr>";

    $primary = !$primary;
  }
  $answer .= "</table>";
  return $answer;


}

sub retrCrsAll2 {

  my @result = @_;

  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>From</td>
        <td>To</td><td>Rate</td><td>Circuit ID</td></tr>";

  my $primary = 1;
  foreach my $circuit (@result) {

    my $in = $circuit->{'from_aid'};
    my $out = $circuit->{'to_aid'};
    my $rate = $circuit->{'rate'};
    my $id = $circuit->{'description'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $answer .= "<tr class=\"$class\"><td>$in</td><td>$out</td>
                  <td>$rate</td><td>$id</td></tr>";

    $primary = !$primary;
  }

  $answer .= "</table>";
  return $answer;
}

sub retrCrsAll {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>Name</td><td>From</td>
        <td>To</td><td>Rate</td><td>State</td></tr>";

  my $primary = 1;

  foreach my $circuit (@result) {

    my $name = $circuit->{'description'};

    my $in = $circuit->{'from_aid'};
    my $out = $circuit->{'to_aid'};

    my $rate = $circuit->{'rate'};
    my $prime = $circuit->{'state'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $answer .= "
              <tr class=\"$class\"><td>$name</td><td>$in</td><td>$out</td><td>$rate</td><td>$prime</td></tr>";
  }

  $answer .= "</table>";
  return $answer;
}

sub retrEqpt {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>ID</td><td>Name</td><td>Type</td>
        <td>Serial</td><td>Firmware</td><td>Software</td><td>Hardware</td><td>CLEI</td></tr>";

  my $primary = 1;

  foreach my $hw (@result) {

    my $id = $hw->{'aid'};
    my $name = $hw->{'name'};
    my $type = $hw->{'type'};
    my $serial = $hw->{'serial'};
    my $firmware = $hw->{'firmware'};
    my $software = $hw->{'software_version'};
    my $hardware = $hw->{'version'};
    my $clei = $hw->{'clei'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }

    $answer .= "
              <tr class=\"$class\"><td>$id</td><td>$name</td><td>$type</td>
                  <td>$serial</td><td>$firmware</td>
                  <td>$software</td><td>$hardware</td><td>$clei</td></tr>";

    $primary = !$primary;
  }

  $answer .= "</table>";
  return $answer;

}

sub retrInv {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>ID</td><td>Type</td>
        <td>Part Number</td><td>Hardware Revision</td><td>Firmware Revision</td>
        <td>Serial</td><td>CLEI</td></tr>";

  my $primary = 1;

  foreach my $hw (@result) {

    my $name = $hw->{'aid'};
    my $type = $hw->{'type'};
    my $partNum = $hw->{'part_number'};
    my $hwRev = $hw->{'version'};
    my $fwRev = $hw->{'firmware'};
    my $serial = $hw->{'serial'};
    my $clei = $hw->{'clei'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }

    $answer .= "
              <tr class=\"$class\"><td>$name</td><td>$type</td>
                  <td>$partNum</td><td>$hwRev</td><td>$fwRev</td>
                  <td>$serial</td><td>$clei</td></tr>";

    $primary = !$primary;
  }

  $answer .= "</table>";
  return $answer;
}

sub retrInventory2 {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>ID</td><td>Description</td><td>Product Code</td>
        <td>Release</td><td>CLEI</td><td>Serial</td>
        <td>Manufac. Date</td></tr>";

  my $primary = 1;

  foreach my $hw (@result) {

    my $name = $hw->{'aid'};
    my $type = $hw->{'type'};
    my $pec = $hw->{'pec'};
    my $release = $hw->{'version'};
    my $clei = $hw->{'clei'};
    my $serial = $hw->{'serial'};
    my $date = $hw->{'date'};

    my $class;
    if ($primary) {

      $class  = "primary";
    }
    else {
      $class = "secondary";
    }
    $answer .= "
              <tr class=\"$class\"><td>$name</td><td>$type</td><td>$pec</td>
                  <td>$release</td><td>$clei</td><td>$serial</td>
                  <td>$date</td></tr>";

    $primary = !$primary;
  }

  $answer .= "</table>";
  return $answer;
}

sub retrInventory {

  my @result = @_;

  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>ID</td><td>Product Code</td>
        <td>Manufac. Date</td><td>Type</td><td>Subtype</td>
        <td>Release Ver.</td><td>Serial</td><td>CLEI</td></tr>";

  my $primary = 1;

  foreach my $hw (@result) {

    my $name = $hw->{'aid'};
    my $pec = $hw->{'pec'};

    my $date = $hw->{'date'};
    my $type = $hw->{'type'};

    my $subtype = $hw->{'subtype'};
    if ($subtype eq "NULL") {
      $subtype = "";
    }

    my $release = $hw->{'version'};
    my $serial = $hw->{'serial'};
    my $clei = $hw->{'clei'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $answer .= "
              <tr class=\"$class\"><td>$name</td><td>$pec</td><td>$date</td>
                  <td>$type</td><td>$subtype</td><td>$release</td>
                  <td>$serial</td><td>$clei</td></tr>";
  }

  $answer .= "</table>";

  return $answer;
}

sub retrFac {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>Facility</td><td>Payload</td>
        <td>Primary State/Qualifier</td></tr>";

  my $primary = 1;
  foreach my $device (@result) {

    my $fac = $device->{'fac'};
    my $payload = $device->{'payload'};
    my $prime = $device->{'prime'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";

    }

    $answer .= "
              <tr class=\"$class\"><td>$fac</td><td>$payload</td>
                  <td>$prime</td></tr>";
    $primary = !$primary;
  }

  $answer .= "</table>";
  return $answer;
}

sub retrNeGen {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>Name</td><td>IP Address</td>
        <td>Netmask</td><td>Gateway</td></tr>";

  my $primary = 1;
  foreach my $device (@result) {

    my $name = $device->{'name'};
    my $ip = $device->{'ip'};
    my $netmask = $device->{'netmask'};
    my $gateway = $device->{'gateway'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }

    $answer .= "<tr class=\"$class\"><td>$name</td><td>$ip</td>
                  <td>$netmask</td><td>$gateway</td></tr>";

    $primary = !$primary;
  }
  $answer .= "</table>";
  return $answer;
}

sub retrIp2 {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>Device</td><td>IP Address</td>
        <td>Netmask</td><td>Broadcast</td><td>TTL</td>
        <td>Host Only</td><td>Non Routing</td></tr>";

  my $primary = 1;

  foreach my $device (@result) {

    my $intf = $device->{'device'};
    my $ip = $device->{'ip'};
    my $netmask = $device->{'netmask'};
    my $bast = $device->{'bcast'};
    my $ttl = $device->{'ttl'};
    my $hostOnly = $device->{'hostOnly'};
    my $noRoute = $device->{'noRoute'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $answer .= "
              <tr class=\"$class\"><td>$intf</td><td>$ip</td>
                  <td>$netmask</td><td>$bast</td>
                  <td>$ttl</td><td>$hostOnly</td>
                  <td>$noRoute</td></tr>";
    $primary = !$primary;
  }

  $answer .= "</table>";
  return $answer;
}

sub retrIp {

  my @result = @_;
  my $answer = "
<table class=\"no-border\">
      <tr class=\"title\"><td>Device</td><td>IP Address</td>
        <td>Netmask</td><td>Gateway</td></tr>";

  my $primary = 1;

  foreach my $device (@result) {

    my $intf = $device->{'device'};
    my $netmask = $device->{'netmask'};
    my $ip = $device->{'ip'};
    my $gateway = $device->{'gateway'};

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $answer .= "
              <tr class=\"$class\"><td>$intf</td><td>$ip</td>
                  <td>$netmask</td><td>$gateway</td></tr>";
  }

  $answer .= "</table>";
  return $answer;
}

sub showArpNoResolve {

  my $xml = shift;

  my $arps = $xml->{'arp-table-entry'};

  print qq {
      <P>
      <TABLE class="info" cellspacing="0" cellpadding="4">
        <TR class="title"><TD class="title">MAC Address</TD><TD class="title">IP Address</TD>
          <TD class="title">Interface</TD>
        </TR>
    };

  my $primary = 1;

  for ($i = 0; $i < @$arps; $i++) {

    my $arp = $arps->[$i];
    my $mac = $arp->{'mac-address'}->[0];
    my $ip = $arp->{'ip-address'}->[0];
    my $intf = $arp->{'interface-name'}->[0];

    if ($primary) {

      print qq {
              <TR><TD class="primary">$mac</TD><TD class="primary">$ip</TD>
                  <TD class="primary">$intf</TD></TR>
            };
    }

    else {

      print qq {
              <TR><TD>$mac</TD><TD>$ip</TD>
                  <TD>$intf</TD></TR>
            };
    }

    $primary = !$primary;
  }
}

sub showBgpSummary {

  my $xml = shift;

  if ($xml eq "BGP is not running") {

    return $xml;
  }

  my $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Table</td><td>Total Paths</td><td>Active Paths</td>
          <td>Suppressed</td><td>History</td><td>Damp State</td><td>Pending</td>
        </tr>";


  my $bgpRibs = $xml->{'bgp-rib'};

  my $primary = 1;

  for ($i = 0; $i < @$bgpRibs; $i++) {

    my $bgpRib = $bgpRibs->[$i];
    my $name = $bgpRib->{'name'}->[0];
    my $totalPaths = $bgpRib->{'total-external-prefix-count'}->[0];
    my $activePaths = $bgpRib->{'active-prefix-count'}->[0];
    my $suppressed = $bgpRib->{'suppressed-external-prefix-count'}->[0];
    my $history = $bgpRib->{'history-prefix-count'}->[0];
    my $dampState = $bgpRib->{'damped-prefix-count'}->[0];
    my $pending = $bgpRib->{'pending-prefix-count'}->[0];

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $result .= "
              <TR class=\"$class\"><td>$name</td><td>$totalPaths</td><td>$activePaths</td>
                  <td>$suppressed</td><td>$history</td><td>$dampState</td>
                  <td>$pending</td></TR>";

    $primary = !$primary;
  }
  $result .= "</table>";

  # get BGP peers
  my $bgpPeers = $xml->{'bgp-peer'};

  $result .= "
<table class=\"no-border\">
                   <tr class=\"title\"><td>Peer</td><td>AS</td><td>InPkt</td>
                     <td>OutPkt</td><td>OutQ</td><td>Flaps</td>
                     <td>Last Up/Down</td><td>State</td><td>Description</td></tr>";

  $primary = 1;

  for ($i = 0; $i < @$bgpPeers; $i++) {

    my $peer = $bgpPeers->[$i];
    my $address = $peer->{'peer-address'}->[0];
    my $as = $peer->{'peer-as'}->[0];
    my $in = $peer->{'input-messages'}->[0];
    my $out = $peer->{'output-messages'}->[0];
    my $outQ = $peer->{'route-queue-count'}->[0];
    my $flaps = $peer->{'flap-count'}->[0];
    my $time = $peer->{'elapsed-time'}->[0]->{'content'};
    my $state;
    my $stateTest = $peer->{'peer-state'}->[0];

    if (scalar($stateTest) > 0) {
      $state = $stateTest->{'content'};
    }
    else {
      $state = $stateTest;
    }

    my $desc = $peer->{'description'}->[0];

    my $class;
    if ($primary) {

      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $result .= "<tr class=\"$class\"><td>$address</td><td>$as</td>
                          <td>$in</td><td>$out</td><td>$outQ</td>
                          <td>$flaps</td><td>$time</td><td>$state</td><td>$desc</td></tr>";

    $primary = !$primary;
  }

  $result .= "</table>";
  return $result;
}

sub showChassisEnvironment {

  my $xml = shift;
  my $items = $xml->{'environment-item'};
  my @powerSupplyStatus;
  my @powerSupplyNames;
  my @tempStatus;
  my @tempNames;
  my @temp;
  my @fanNames;
  my @fanStatus;
  my @fanSpeed;

  # Get power supplies
  my $deviceNum = 0;

  while ($deviceNum < @$items) {

    my $class = $items->[$deviceNum]->{'class'};

    if ($class) {
      if ($class->[0] eq "Temp") {
        last;
      }
    }
    push(@powerSupplyStatus, $items->[$deviceNum]->{'status'}->[0]);
    push(@powerSupplyNames, $items->[$deviceNum]->{'name'}->[0]);

    $deviceNum++;
  }

  # Get device temperatures
  while ($deviceNum < @$items) {

    my $class = $items->[$deviceNum]->{'class'};

    if ($class) {
      if ($class->[0] eq "Fans") {
        last;
      }
    }
    push(@tempStatus, $items->[$deviceNum]->{'status'}->[0]);
    push(@tempNames, $items->[$deviceNum]->{'name'}->[0]);
    push(@temp, $items->[$deviceNum]->{'temperature'}->[0]->{'content'});

    $deviceNum++;
  }

  # Get fans
  while ($deviceNum < @$items) {

    my $class = $items->[$deviceNum]->{'class'};

    if ($class) {
      if ($class->[0] eq "Misc") {
        last;
      }
    }
    push(@fanStatus, $items->[$deviceNum]->{'status'}->[0]);
    push(@fanNames, $items->[$deviceNum]->{'name'}->[0]);
    push(@fanSpeed, $items->[$deviceNum]->{'comment'}->[0]);

    $deviceNum++;
  }

  # Print Power Supply table
  my $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Power Supply</td><td>Status</td></tr>";

  my $primary = 1;
  for ($i = 0; $i < @powerSupplyNames; $i++) {

    my $psName = $powerSupplyNames[$i];
    my $psStatus = $powerSupplyStatus[$i];

    my $class;
    if ($primary) {
      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $result .= "
        <tr class=\"$class\"><td>$psName</td><td>$psStatus</td></tr>";
  }
  $result .= "</table>";

  # Print Temperature table
  $result .= "
<table class=\"no-border\">
        <tr class=\"title\"><td>Device</td><td>Status</td><td>Temperature</td></tr>";

  $primary = 1;
  for ($i = 0; $i < @tempNames; $i++) {

    my $tempName = $tempNames[$i];
    my $tempS = $tempStatus[$i];
    my $tempTemp = $temp[$i];

    my $class;
    if ($primary) {
      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $result .= "<tr class=\"$class\"><td>$tempName</td><td>$tempS</td><td>$tempTemp</td></tr>";
  }

  $result .= "</table>";

  # Print Fan table
  $result .= "
<table class=\"no-border\">
        <tr class=\"title\"><td>Fan</td><td>Status</td><td>Speed</td></tr>";

  $primary = 1;
  for ($i = 0; $i < @fanNames; $i++) {

    my $fanName = $fanNames[$i];
    my $fanS = $fanStatus[$i];
    my $fanSp = $fanSpeed[$i];

    my $class;
    if ($primary) {
      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $result .= "<tr class=\"$class\"><td>$fanName</td><td>$fanS</td><td>$fanSp</td></tr>";
  }

  $result .= "</table>";
  return $result;
}

sub showChassisHardware {

  my $xml = shift;
  my $length;
  my $otherLength;

  # get main chassis info
  my $chassis = $xml->{'chassis'}->[0];
  my $name = $chassis->{'name'}->[0];
  my $serial = $chassis->{'serial-number'}->[0];
  my $desc = $chassis->{'description'}->[0];

  my $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>Item</td><td>Version</td>
          <td>Part Number</td>
          <td>Serial Number</td>
          <td>Description</td>
        </tr>
        <tr class=\"primary\">
          <td>$name</td><td></td><td></td><td>$serial</td><td>$desc</td>
        </tr>";

  # get chassis modules
  my $modules = $chassis->{'chassis-module'};

  my $primary = 0;

  for ($i = 0; $i < scalar(@$modules); $i++) {

    my $mod = $modules->[$i];
    my $name = $mod->{'name'}->[0];
    my $version = $mod->{'version'}->[0];
    my $partNo = $mod->{'part-number'}->[0];
    my $serial = $mod->{'serial-number'}->[0];
    my $desc = $mod->{'description'}->[0];

    my $class;
    if ($primary) {
      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $result .= "<tr class=\"$class\"><td>$name</td><td>$version</td><td>$partNo</td>
                          <td>$serial</td><td>$desc</td></tr>";

    # get chassis sub-modules
    my $subModules = $mod->{'chassis-sub-module'};
    if ($subModules eq "") {
      $length = 0;
    }
    else {
      $length = scalar(@$subModules);
    }

    for ($j = 0; $j < $length; $j++) {

      my $subMod = $subModules->[$j];
      my $name = $subMod->{'name'}->[0];
      my $version = $subMod->{'version'}->[0];
      my $partNo = $subMod->{'part-number'}->[0];
      my $serial = $subMod->{'serial-number'}->[0];
      my $desc = $subMod->{'description'}->[0];

      if ($primary) {
        $class = "primary";
      }
      else {
        $class = "secondary";
      }
      $primary = !$primary;

      $result .= "<tr class=\"$class\"><td>$name</td><td>$version</td><td>$partNo</td><td>$serial</td><td>$desc</td></tr>";

      # get chassis sub-sub-modules
      my $subSubModules = $subMod->{'chassis-sub-sub-module'};
      if ($subSubModules eq "") {
        $otherLength = 0;
      }
      else {
        $otherLength = scalar(@$subSubModules);
      }

      for ($k = 0; $k < $otherLength; $k++) {

        my $subSubMod = $subSubModules->[$k];
        my $name = $subSubMod->{'name'}->[0];
        my $version = $subSubMod->{'version'}->[0];
        my $partNo = $subSubMod->{'part-number'}->[0];
        my $serial = $subSubMod->{'serial-number'}->[0];
        my $desc = $subSubMod->{'description'}->[0];

        if ($primary) {
          $class = "primary";
        }
        else {
          $class = "secondary";
        }
        $primary = !$primary;

        $result .= "<tr class=\"$class\"><td>$name</td><td>$version</td><td>$partNo</td><td>$serial</td><td>$desc</td></tr>";
      }
    }
  }

  $result .= "</table>";
  return $result;
}

sub showChassisRoutingEngine {

  my $xml = shift;

  my $routingEngines = $xml->{'route-engine'};

  print qq {
          <P>
          <TABLE class="info" cellspacing="0" cellpadding="4" width="900">
        };

  foreach my $routeEngine (@$routingEngines) {

    my $slot = $routeEngine->{'slot'}->[0];
    my $currentState = $routeEngine->{'mastership-state'}->[0];
    my $electionPriority = $routeEngine->{'mastership-priority'}->[0];
    my $temp = $routeEngine->{'temperature'}->[0]->{'content'};
    my $cpuTemp = $routeEngine->{'cpu-temperature'}->[0]->{'content'};
    my $dram = $routeEngine->{'memory-dram-size'}->[0];
    my $memoryUtil = $routeEngine->{'memory-buffer-utilization'}->[0];
    my $cpuUser = $routeEngine->{'cpu-user'}->[0];
    my $cpuBackground = $routeEngine->{'cpu-background'}->[0];
    my $cpuKernel = $routeEngine->{'cpu-system'}->[0];
    my $cpuInterrupt = $routeEngine->{'cpu-interrupt'}->[0];
    my $cpuIdle = $routeEngine->{'cpu-idle'}->[0];
    my $model = $routeEngine->{'model'}->[0];
    my $serial = $routeEngine->{'serial-number'}->[0];
    my $startTime = $routeEngine->{'start-time'}->[0]->{'content'};
    my $uptime = $routeEngine->{'up-time'}->[0]->{'content'};
    my $loadAvg1 = $routeEngine->{'load-average-one'}->[0];
    my $loadAvg5 = $routeEngine->{'load-average-five'}->[0];
    my $loadAvg15 = $routeEngine->{'load-average-fifteen'}->[0];

    print qq {
          <P>
          <TABLE class="info" cellspacing="0" cellpadding="4" width="900">
          <tr class="title"><TD class="title" colspan="2">Routing Engine Information</TD></tr>
          <tr><TD class="primary">Slot</TD><TD class="primary">$slot</TD></tr>
          <tr><TD>Current State</TD><TD>$currentState</TD></tr>
          <tr><TD class="primary">Election Priority</TD><TD class="primary">$electionPriority</TD></tr>
          <tr><TD>Temperature</TD><TD>$temp</TD></tr>
          <tr><TD class="primary">CPU Temperature</TD><TD class="primary">$cpuTemp</TD></tr>
          <tr><TD>DRAM</TD><TD>$dram</TD></tr>
          <tr><TD class="primary">Memory Utilization</TD><TD class="primary">$memoryUtil%</TD></tr>
          <tr><TD>CPU User</TD><TD>$cpuUser%</TD></tr>
          <tr><TD class="primary">CPU Background</TD><TD class="primary">$cpuBackground%</TD></tr>
          <tr><TD>CPU Kernel</TD><TD>$cpuKernel%</TD></tr>
          <tr><TD class="primary">CPU Interrupt</TD><TD class="primary">$cpuInterrupt%</TD></tr>
          <tr><TD>CPU Idle</TD><TD>$cpuIdle%</TD></tr>
          <tr><TD class="primary">Model</TD><TD class="primary">$model</TD></tr>
          <tr><TD>Serial</TD><TD>$serial</TD></tr>
          <tr><TD class="primary">Start Time</TD><TD class="primary">$startTime</TD></tr>
          <tr><TD>Uptime</TD><TD>$uptime</TD></tr>
          <tr><TD class="primary">Load Avg (1 min)</TD><TD class="primary">$loadAvg1</TD></tr>
          <tr><TD>Load Avg (5 min)</TD><TD>$loadAvg5</TD></tr>
          <tr><TD class="primary">Load Avg (15 min)</TD><TD class="primary">$loadAvg15</TD></tr>
          </TABLE>
          </P>
        };
  }
}

sub showChassisSpmb {

  my $xml = shift;

  my $spmbs = $xml->{'spmb'};

  foreach my $spmb (@$spmbs) {

    my $slot = $spmb->{'slot'}->[0];
    my $state = $spmb->{'state'}->[0];
    my $totalCpu = $spmb->{'cpu-total'}->[0];
    my $interruptCpu = $spmb->{'cpu-interrupt'}->[0];
    my $memoryHeap = $spmb->{'memory-heap-utilization'}->[0];
    my $buffer = $spmb->{'memory-buffer-utilization'}->[0];
    my $startTime = $spmb->{'start-time'}->[0]->{'content'};
    my $uptime = $spmb->{'up-time'}->[0]->{'content'};

    print qq {

          <P>
          <TABLE class="info" cellspacing="0" cellpadding="4" width="900">
          <tr class="title"><TD class="title" colspan="2">SPMB Information</TD></tr>
          <tr><TD class="primary">Slot</TD><TD class="primary">$slot</TD></tr>
          <tr><TD>State</TD><TD>$state</TD></tr>
          <tr><TD class="primary">Total CPU</TD><TD class="primary">$totalCpu%</TD></tr>
          <tr><TD>Interrupt CPU</TD><TD>$interruptCpu%</TD></tr>
          <tr><TD class="primary">Memory Heap</TD><TD class="primary">$memoryHeap%</TD></tr>
          <tr><TD>Buffer</TD><TD>$buffer%</TD></tr>
          <tr><TD class="primary">Start Time</TD><TD class="primary">$startTime</TD></tr>
          <tr><TD>Uptime</TD><TD>$uptime</TD></tr>
          </TABLE>
          </P>
        };
  }
}

sub showConfiguration {

  my $xml = shift;

  my $conf = $xml->{'configuration-output'}->[0];

  # fix HTML
  $conf =~ s/</&lt;/g;
  $conf =~ s/>/&gt;/g;
  $conf =~ s/\n/<br>/g;
  $conf =~ s/ /&nbsp;/g;

  print qq {
      <P>
      <TABLE class="info" cellspacing="0" cellpadding="4">
        <TR class="title"><TD class="title">Configuration File</TD></TR>
        <TR><TD class="primary">$conf</TD></TR>
      </TABLE>
      </P>
    };
}

sub showFirewall {

  my $xml = shift;

  my $filters = $xml->{'filter-information'};

  for ($i = 0; $i < @$filters; $i++) {

    my $name = $filters->[$i]->{'filter-name'}->[0];

    print qq {
          <P><TABLE class="info" cellspacing="0" cellpadding="4">
            <TR class="title"><TD class="title" colspan="2">Filter: $name</TD></TR>
        };

    my $counters = $filters->[$i]->{'counter'};

    for ($j = 0; $j < @$counters; $j++) {

      my $cname = $filters->[$i]->{'counter'}->[$j]->{'counter-name'}->[0];
      my $packets = $filters->[$i]->{'counter'}->[$j]->{'packet-count'}->[0];
      my $bytes = $filters->[$i]->{'counter'}->[$j]->{'byte-count'}->[0];

      print qq {
              <TR><TD class="primary">Counter</TD><TD class="primary">$cname</TD></TR>
              <TR><TD>Packets</TD><TD>$packets</TD></TR>
              <TR><TD class="primary" style="border-bottom: solid black 1px;">Bytes</TD><TD class="primary" style="border-bottom: solid black 1px;">$bytes</TD></TR>
            };

    }
    print qq {</TABLE></P>};
  }
}

sub showInterfaces {

  my $xml = shift;

  my $result;

  my $physicalInterfaces = $xml->{'physical-interface'};

  for ($i = 0; $i < @$physicalInterfaces; $i++) {

    my $if = $physicalInterfaces->[$i];
    my $name = $if->{'name'}->[0];
    my $desc = $if->{'description'}->[0];
    my $enabled = $if->{'admin-status'}->[0]->{'format'};
    my $link = $if->{'oper-status'}->[0];
    my $ifIndex = $if->{'local-index'}->[0];
    my $snmpIndex = $if->{'snmp-index'}->[0];
    my $linkType = $if->{'link-level-type'}->[0];
    my $mtu = $if->{'mtu'}->[0];
    my $speed = $if->{'speed'}->[0];
    my $loopback = $if->{'loopback'}->[0];
    my $sourceFiltering = $if->{'source-filtering'}->[0];
    my $flowControl = $if->{'if-flow-control'}->[0];
    my $cosQueues = $if->{'physical-interface-cos-information'}->[0]->{'physical-interface-cos-hw-max-queues'}->[0];

    if ($cosQueues eq "") {
    }

    else {
      $cosQueues = "$cosQueues supported";
    }

    my $test = $if->{'current-physical-address'}->[0];
    my $currentAddress;

    if (ref($test) eq "SCALAR") {

      $currentAddress = $test;
    }

    elsif (ref($test) eq "HASH") {

      $currentAddress = $test->{'content'};
    }
    else {

      $currentAddress = "";
    }

    $test = $if->{'hardware-physical-address'}->[0];
    my $physicalAddress;

    if (ref($test) eq "SCALAR") {

      $physicalAddress = $test;
    }
    elsif (ref($test) eq "HASH") {

      $physicalAddress = $test->{'content'};
    }
    else {
      $physicalAddress = "";
    }

    my $lastFlapped = $if->{'interface-flapped'}->[0]->{'content'};

    $test = $if->{'traffic-statistics'}->[0]->{'input-bps'};

    my $inputRateBPS;
    my $inputRatePPS;
    my $outputRateBPS;
    my $outputRatePPS;
    my $inputPackets;
    my $outputPackets;

    if ($test) {

      my $rate = $if->{'traffic-statistics'}->[0];
      $inputRateBPS = $rate->{'input-bps'}->[0];
      $inputRateBPS = "$inputRateBPS bps";
      $inputRatePPS = $rate->{'input-pps'}->[0];
      $inputRatePPS = "($inputRatePPS pps)";
      $outputRateBPS = $rate->{'output-bps'}->[0];
      $outputRateBPS = "$outputRateBPS bps";
      $outputRatePPS = $rate->{'output-pps'}->[0];
      $outputRatePPS = "($outputRatePPS pps)";
    }

    else {
      $inputRateBPS = "";
      $inputRatePPS = "";
      $outputRateBPS = "";
      $outputRatePPS = "";
    }

    $test = $if->{'traffic-statistics'}->[0]->{'input-packets'};

    if ($test) {

      my $inputPackets = $test->[0];
      my $outputPackets = $if->{'traffic-statistics'}->[0]->{'output-packets'}->[0];
    }

    else {
      my $inputPackets = "";
      my $outputPackes = "";
    }

    $result .= "
<table class=\"no-border\">
        <tr style=\"border-bottom: 1px solid black;\" class=\"title\"><td>$name</td><td>$enabled</td>
          <td class>Physical link is $link</td></tr>
</table>
<table class=\"no-border\" style=\"border-bottom: 1px solid black;\">
        <tr class=\"title\"><td>Property</td><td>Info</td></tr>
        <tr class=\"primary\"><td>Interface Index</td><td>$ifIndex</td></tr>
        <tr class=\"secondary\"><td>SNMP Interface Index</td><td>$snmpIndex</td></tr>
        <tr class=\"primary\"><td>Description</td><td>$desc</td></tr>
        <tr class=\"secondary\"><td>Link Level Type</td><td>$linkType</td></tr>
        <tr class=\"primary\"><td>MTU</td><td>$mtu</td></tr>
        <tr class=\"secondary\"><td>Speed</td><td>$speed</td></tr>
        <tr class=\"primary\"><td>Loopback</td><td>$loopback</td></tr>
        <tr class=\"secondary\"><td>Source Filtering</td><td>$sourceFiltering</td></tr>
        <tr class=\"primary\"><td>Flow Control</td><td>$flowControl</td></tr>
        <tr class=\"secondary\"><td>CoS Queues</td><td>$cosQueues</td></tr>
        <tr class=\"primary\"><td>Current Address</td><td>$currentAddress</td></tr>
        <tr class=\"secondary\"><td>Hardware Address</td><td>$physicalAddress</td></tr>
        <tr class=\"primary\"><td>Last Flapped</td><td>$lastFlapped</td></tr>
        <tr class=\"secondary\"><td>Input Rate</td><td>$inputRateBPS $inputRatePPS</td></tr>
        <tr class=\"primary\"><td>Output Rate</td><td>$outputRateBPS $outputRatePPS</td></tr>
        <tr class=\"secondary\"><td>Input Packets</td><td>$inputPackets</td></tr>
        <tr class=\"primary\"><td>Output Packets</td><td>$outputPackets</td></tr>";

    # Check for logical interfaces
    my $logicals = $if->{'logical-interface'};

    if ($logicals) {

      for ($j = 0; $j < @$logicals; $j++) {

        my $lif = $logicals->[$j];
        my $name = $lif->{'name'}->[0];
        my $index = $lif->{'local-index'}->[0];
        my $snmpIndex = $lif->{'snmp-index'}->[0];
        my $desc = $lif->{'description'}->[0];
        my $encap = $lif->{'encapsulation'}->[0];
        my $inputPackets = $lif->{'traffic-statistics'}->[0]->{'input-packets'}->[0];
        my $outputPackets = $lif->{'traffic-statistics'}->[0]->{'output-packets'}->[0];
        my $addresses = $lif->{'address-family'};

        $result .= "
                <tr class=\"title\"><td colspan=\"2\">Logical Interface $name</td></tr>
                <tr class=\"primary\"><td>Index</td><td>$index</td></tr>
                <tr class=\"secondary\"><td>SNMP Index</td><td>$snmpIndex</td></tr>
                <tr class=\"primary\"><td>Description</td><td>$desc</td></tr>
                <tr class=\"secondary\"><td>Encapsulation</td><td>$encap</td></tr>
                <tr class=\"primary\"><td>Input Packets</td><td>$inputPackets</td></tr>
                <tr class=\"secondary\"><td>Output Packets</td><td>$outputPackets</td></tr>";

        for ($k = 0; $addresses ne "" && $k < @$addresses; $k++) {

          my $addr = $addresses->[$k];
          my $proto = $addr->{'address-family-name'}->[0];
          my $mtu = $addr->{'mtu'}->[0];
          my $addrs = $addr->{'interface-address'}->[0];
          my $destAddr = $addrs->{'ifa-destination'}->[0];
          my $localAddr = $addrs->{'ifa-local'}->[0];
          my $broadAddr = $addrs->{'ifa-broadcast'}->[0];

          $result .= "
                <tr class=\"primary\" style=\"border-top: 1px solid black;\"><td>Protocol</td><td>$proto</td></tr>
                <tr class=\"secondary\"><td>MTU</td><td>$mtu</td></tr>
                <tr class=\"primary\"><td>Destination Address</td><td>$destAddr</td></tr>
                <tr class=\"secondary\"><td>Local Address</td><td>$localAddr</td></tr>
                <tr class=\"primary\"><td>Broadcast Address</td><td>$broadAddr</td></tr>";
        }
      }
    }

    $result .= "</table><br>";
  }

  return $result;
}

sub showIpv6Neighbors {

  my $xml = shift;
  my $neighbors = $xml->{'ipv6-nd-entry'};
  if ($neighbors eq "") {

    return "<center>There are no neighbors.</center>";
  }

  my $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td>IPv6 Address</td><td>MAC Address</td><td>State</td>
          <td>Expire</td><td>Router</td><td>Interface</td></tr>";

  my $primary = 1;

  for ($i = 0; $i < @$neighbors; $i++) {

    my $neighbor = $neighbors->[$i];
    my $addr = $neighbor->{'ipv6-nd-neighbor-address'}->[0];

    # sometimes its like this ....
    if (ref($addr) eq "HASH") {
      $addr = $addr->{'content'};
    }

    my $mac = $neighbor->{'ipv6-nd-neighbor-l2-address'}->[0];
    my $state = $neighbor->{'ipv6-nd-state'}->[0];
    my $expire = $neighbor->{'ipv6-nd-expire'}->[0];
    my $router = $neighbor->{'ipv6-nd-isrouter'}->[0];
    my $intf = $neighbor->{'ipv6-nd-interface-name'}->[0];

    my $class;

    if ($primary) {
      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $result .= "
              <tr class=\"$class\"><td>$addr</td><td>$mac</td><td>$state</td>
                  <td>$expire</td><td>$router</td><td>$intf</td></tr>";
  }

  $result .= "</table>";

  return $result;
}

sub showIsisAdjacency {

  my $xml = shift;

  if ($xml eq "IS-IS instance is not running") {
    return $xml;
  }
  else {

    my $result = "
<table class=\"no-border\">
            <tr class=\"title\"><td>Interface</td><td>System</td><td>Level</td>
              <td>State</td><td>Hold (secs)</td></tr>";

    my $guys = $xml->{'isis-adjacency'};
    my $primary = 1;

    for my $guy (@$guys) {

      my $intf = $guy->{'interface-name'}->[0];
      my $system = $guy->{'system-name'}->[0];
      my $level = $guy->{'level'}->[0];
      my $state = $guy->{'adjacency-state'}->[0];
      my $hold = $guy->{'holdtime'}->[0];

      my $class;
      if ($primary) {
        $class = "primary";
      }
      else {
        $class = "secondary";
      }
      $primary = !$primary;

      $result .= "<tr class=\"$class\"><td>$intf</td><td>$system</td><td>$level</td><td>$state</td><td>$hold</td></tr>";
    }

    $result .= "</table>";
    return $result;
  }
}

sub showMsdpDetail {

  my $xml = shift;

  if ($xml eq "MSDP instance is not running") {

    return "MSDP instance is not running";
  }
  else {

    my $result = "
<table class=\"no-border\">
            <tr class=\"title\"><td>Peer</td><td>Local Address</td><td>State</td>
              <td>Connect Retries</td><td>State Timer Expires</td>
              <td>Peer Times Out</td><td>SA accepted</td><td>SA received</td></tr>
        ";

    my $peers = $xml->{'msdp-peer'};

    my $primary = 1;

    for ($i = 0; $i < @$peers; $i++) {

      my $peer = $peers->[$i];
      my $addr = $peer->{'msdp-peer-address'}->[0];
      my $localAddr = $peer->{'msdp-local-address'}->[0];
      my $state = $peer->{'msdp-state'}->[0];
      my $retries = $peer->{'msdp-connect-retries'}->[0];
      my $stateTimeout = $peer->{'msdp-state-timeout'}->[0];
      my $peerTimeout = $peer->{'msdp-peer-timeout'}->[0];
      my $accepted = $peer->{'msdp-sa-accepted'}->[0];
      my $received = $peer->{'msdp-sa-received'}->[0];

      my $class;

      if ($primary) {
        $class = "primary";
      }
      else {
        $class = "secondary";
      }
      $primary = !$primary;

      $result .= "
                  <tr class=\"$class\"><td>$addr</td><td>$localAddr</td><td>$state</td>
                      <td>$retries</td><td>$stateTimeout</td><td>$peerTimeout</td>
                      <td>$accepted</td><td>$received</td></tr>";
    }

    $result .= "</table>";
    return $result;
  }
}

sub showMulticastStatistics {

  my $xml = shift;

  if ($xml eq "instance is not running") {

    return "Multicast instance is not running";
  }

  else {

    my $multStats = $xml->{'multicast-statistics'};
    my $result;

    for ($i = 0; $i < @$multStats; $i++) {

      my $instance = $multStats->[$i]->{'instance-name'}->[0];
      my $addrFamily = $multStats->[$i]->{'address-family'}->[0];

      $result .= "
<table class=\"no-border\">
                <tr class=\"title\"><td>Instance: $instance</td><td>Address Family: $addrFamily</td></tr>";

      my $ifs = $multStats->[$i]->{'mc-stats-interface'};

      for ($j = 0; $j < @$ifs; $j++) {

        my $name = $ifs->[$j]->{'interface-name'}->[0];
        my $route = $ifs->[$j]->{'protocol-name'}->[0];
        my $mismatch = $ifs->[$j]->{'mc-mismatches'}->[0];
        my $mismatchError = $ifs->[$j]->{'mc-mismatch-errors'}->[0];
        my $mismatchNoRoute = $ifs->[$j]->{'mc-mismatches-no-route'}->[0];
        my $routeNotify = $ifs->[$j]->{'mc-routing-notifies'}->[0];
        my $kernelResolve = $ifs->[$j]->{'mc-resolves'}->[0];
        my $resolveError = $ifs->[$j]->{'mc-resolve-errors'}->[0];
        my $resolveNoRoute = $ifs->[$j]->{'mc-resolves-no-route'}->[0];
        my $resolveFiltered = $ifs->[$j]->{'mc-resolves-filtered'}->[0];
        my $notifyFiltered = $ifs->[$j]->{'mc-routing-notifies-filtered'}->[0];
        my $inPackets = $ifs->[$j]->{'mc-input-packets'}->[0];
        my $inKbytes = $ifs->[$j]->{'mc-input-kbytes'}->[0];
        my $outPackets = $ifs->[$j]->{'mc-output-packets'}->[0];
        my $outKbytes = $ifs->[$j]->{'mc-output-kbytes'}->[0];

        $result .= "
                      <tr class=\"primary\"><td>Interface</td><td>$name</td></tr>
                      <tr class=\"secondary\"><td>Routing Protocol</td><td>$route</td></tr>
                      <tr class=\"primary\"><td>Mismatch</td><td>$mismatch</td></tr>
                      <tr class=\"secondary\"><td>Mismatch Error</td><td>$mismatchError</td></tr>
                      <tr class=\"primary\"><td>Mismatch No Route</td><td>$mismatchNoRoute</td></tr>
                      <tr class=\"secondary\"><td>Routing Notify</td><td>$routeNotify</td></tr>
                      <tr class=\"primary\"><td>Kernel Resolve</td><td>$kernelResolve</td></tr>
                      <tr class=\"secondary\"><td>Resolve Error</td><td>$resolveError</td></tr>
                      <tr class=\"primary\"><td>Resolve No Route</td><td>$resolveNoRoute</td></tr>
                      <tr class=\"secondary\"><td>Resolve Filtered</td><td>$resolveFiltered</td></tr>
                      <tr class=\"primary\"><td>Notify Filtered</td><td>$notifyFiltered</td></tr>
                      <tr class=\"secondary\"><td>In Packets</td><td>$inPackets</td></tr>
                      <tr class=\"primary\"><td>In kbytes</td><td>$inKbytes</td></tr>
                      <tr class=\"secondary\"><td>Out Packets</td><td>$outPackets</td></tr>
                      <tr class=\"primary\" style=\"border-bottom: 1px solid black;\"><td>Out kbytes</td><td>$outKbytes</td></tr>";
      }
      $result .=  "</table>";
    }

    return $result;
  }
}

sub showSnmpStatistics {

  my $xml = shift;

  my $input = $xml->{'snmp-input-statistics'}->[0];

  my $packets = $input->{'packets'}->[0];
  my $badVersions = $input->{'bad-versions'}->[0];
  my $badCommunityNames = $input->{'bad-community-names'}->[0];
  my $badCommunityUses = $input->{'bad-community-uses'}->[0];
  my $asnParseErrors = $input->{'asn-parse-errors'}->[0];
  my $tooBigs = $input->{'too-bigs'}->[0];
  my $noSuchNames = $input->{'no-such-names'}->[0];
  my $badValues = $input->{'bad-values'}->[0];
  my $readOnlys = $input->{'read-onlys'}->[0];
  my $generalErrors = $input->{'general-errors'}->[0];
  my $totalRequestVarbinds = $input->{'total-request-varbinds'}->[0];
  my $totalSetVarbinds = $input->{'total-set-varbinds'}->[0];
  my $getRequests = $input->{'get-requests'}->[0];
  my $getNexts = $input->{'get-nexts'}->[0];
  my $setRequests = $input->{'set-requests'}->[0];
  my $getResponses = $input->{'get-responses'}->[0];
  my $traps = $input->{'traps'}->[0];
  my $silentDrops = $input->{'silent-drops'}->[0];
  my $proxyDrops = $input->{'proxy-drops'}->[0];
  my $commitPendingDrops = $input->{'commit-pending-drops'}->[0];
  my $throttleDrops = $input->{'throttle-drops'}->[0];
  my $duplicateRequestDrops = $input->{'duplicate-request-drops'}->[0];

  my $result = "
<table class=\"no-border\">
        <tr class=\"title\"><td colspan=\"2\" class=\"title\">SNMP Input Statistics</td></tr>
        <tr class=\"primary\"><td>Packets</td><td>$packets</td></tr>
        <tr class=\"secondary\"><td>Bad Versions</td><td>$badVersions</td></tr>
        <tr class=\"primary\"><td>Bad Community Names</td><td>$badCommunityNames</td></tr>
        <tr class=\"secondary\"><td>Bad Community Uses</td><td>$badCommunityUses</td></tr>
        <tr class=\"primary\"><td>ASN Parse Errors</td><td>$asnParseErrors</td></tr>
        <tr class=\"secondary\"><td>Too Bigs</td><td>$tooBigs</td></tr>
        <tr class=\"primary\"><td>No Such Names</td><td>$noSuchNames</td></tr>
        <tr class=\"secondary\"><td>Bad Values</td><td>$badValues</td></tr>
        <tr class=\"primary\"><td>Read Onlys</td><td>$readOnlys</td></tr>
        <tr class=\"secondary\"><td>General Errors</td><td>$generalErrors</td></tr>
        <tr class=\"primary\"><td>Total Request Varbinds</td><td>$totalRequestVarbinds</td></tr>
        <tr class=\"secondary\"><td>Total Set Varbinds</td><td>$totalSetVarbinds</td></tr>
        <tr class=\"primary\"><td>Get Requests</td><td>$getRequests</td></tr>
        <tr class=\"secondary\"><td>Get Nexts</td><td>$getNexts</td></tr>
        <tr class=\"primary\"><td>Set Requests</td><td>$setRequests</td></tr>
        <tr class=\"secondary\"><td>Get Responses</td><td>$getResponses</td></tr>
        <tr class=\"primary\"><td>Traps</td><td>$traps</td></tr>
        <tr class=\"secondary\"><td>Silent Drops</td><td>$silentDrops</td></tr>
        <tr class=\"primary\"><td>Proxy Drops</td><td>$proxyDrops</td></tr>
        <tr class=\"secondary\"><td>Commit Pending Drops</td><td>$commitPendingDrops</td></tr>
        <tr class=\"primary\"><td>Throttle Drops</td><td>$throttleDrops</td></tr>
        <tr class=\"secondary\"><td>Duplicate Request Drops</td><td>$duplicateRequestDrops</td></tr>
</table>";

  my $output = $xml->{'snmp-output-statistics'}->[0];

  my $packets = $output->{'packets'}->[0];
  my $tooBigs = $output->{'too-bigs'}->[0];
  my $noSuchNames = $output->{'no-such-names'}->[0];
  my $badValues = $output->{'bad-values'}->[0];
  my $generalErrors = $output->{'general-errors'}->[0];
  my $getRequests = $output->{'get-requests'}->[0];
  my $getNexts = $output->{'get-nexts'}->[0];
  my $setRequests = $output->{'set-requests'}->[0];
  my $getResponses = $output->{'get-responses'}->[0];
  my $traps = $output->{'traps'}->[0];

  $result .= "
<table class=\"no-border\">
        <tr class=\"title\"><td colspan=\"2\" class=\"title\">SNMP Output Statistics</td></tr>
        <tr class=\"primary\"><td>Packets</td><td>$packets</td></tr>
        <tr class=\"secondary\"><td>Too Bigs</td><td>$tooBigs</td></tr>
        <tr class=\"primary\"><td>No Such Names</td><td >$noSuchNames</td></tr>
        <tr class=\"secondary\"><td>Bad Values</td><td>$badValues</td></tr>
        <tr class=\"primary\"><td>General Errors</td><td>$generalErrors</td></tr>
        <tr class=\"secondary\"><td>Get Requests</td><td>$getRequests</td></tr>
        <tr class=\"primary\"><td>Get Nexts</td><td>$getNexts</td></tr>
        <tr class=\"secondary\"><td>Set Requests</td><td>$setRequests</td></tr>
        <tr class=\"primary\"><td>Get Responses</td><td>$getResponses</td></tr>
        <tr class=\"secondary\"><td>Traps</td><td>$traps</td></tr>
</table>";

  my $input = $xml->{'snmp-v3-input-statistics'}->[0];

  my $unknownSecurityModels = $input->{'unknown-secmodels'}->[0];
  my $invalidMessages = $input->{'invalid-msgs'}->[0];
  my $unknownPduHandlers = $input->{'unknown-pduhandlers'}->[0];
  my $unavailableContexts = $input->{'unavail-contexts'}->[0];
  my $unknownContexts = $input->{'unknown-contexts'}->[0];
  my $unsupportedSecurityLevels = $input->{'unsupported-seclevels'}->[0];
  my $notInTimeWindows = $input->{'not-in-timewindows'}->[0];
  my $unknownUserNames = $input->{'unknown-usernames'}->[0];
  my $unknownEngineIds = $input->{'unknown-eids'}->[0];
  my $wrongDigests = $input->{'wrong-digests'}->[0];
  my $decryptionErrors = $input->{'decrypt-errors'}->[0];

  $result .= "
<table class=\"no-border\">
        <tr class=\"title\"><td colspan=\"2\" class=\"title\">SNMP v3 Input Statistics</td></tr>
        <tr class=\"primary\"><td>Unknown Security Models</td><td>$unknownSecurityModels</td></tr>
        <tr class=\"secondary\"><td>Invalid Messages</td><td>$invalidMessages</td></tr>
        <tr class=\"primary\"><td>Unknown PDU Handlers</td><td>$unknownPduHandlers</td></tr>
        <tr class=\"secondary\"><td>Unavailable Contexts</td><td>$unavailableContexts</td></tr>
        <tr class=\"primary\"><td>Unknown Contexts</td><td>$unknownContexts</td></tr>
        <tr class=\"secondary\"><td>Unsupported Security Levels</td><td>$unsupportedSecurityLevels</td></tr>
        <tr class=\"primary\"><td>Not In Time Windows</td><td>$notInTimeWindows</td></tr>
        <tr class=\"secondary\"><td>Unknown User Names</td><td>$unknownUserNames</td></tr>
        <tr class=\"primary\"><td>Unknown Engine Ids</td><td>$unknownEngineIds</td></tr>
        <tr class=\"secondary\"><td>Wrong Digests</td><td>$wrongDigests</td></tr>
        <tr class=\"primary\"><td>Decryption Errors</td><td>$decryptionErrors</td></tr>
</table>";

  return $result;
}

sub showSystemBootMessages {

  my $result = shift;

  # fix HTML
  $result =~ s/</&lt;/g;
  $result =~ s/>/&gt;/g;
  $result =~ s/\n/<br>/g;

  $result = "
      <table class=\"no-border\">
        <tr class=\"title\"><td>System Boot Messages</td></tr>
        <tr class=\"primary\"><td><code>$result</code></td></tr>
      </table>";

  return $result;
}

sub showSystemStorage {

  my $xml = shift;

  my $filesystems = $xml->{'filesystem'};

  my $result = "
      <table class=\"no-border\">
      <tr class=\"title\">
        <td>Filesystem</td>
        <td>Size</td>
        <td>Used</td>
        <td>Available</td>
        <td>Capacity</td>
        <td>Mount Directory</td>
      </tr>";

  my $primary = 1;

  for ($i = 0; $i < @$filesystems; $i++) {

    my $fs = $filesystems->[$i];
    my $name = $fs->{'filesystem-name'}->[0];
    my $size = $fs->{'total-blocks'}->[0]->{'format'};
    my $used = $fs->{'used-blocks'}->[0]->{'format'};
    my $avail = $fs->{'available-blocks'}->[0]->{'format'};
    my $cap = $fs->{'used-percent'}->[0];
    my $dir = $fs->{'mounted-on'}->[0];

    my $class;

    if ($primary) {
      $class = "primary";
    }
    else {
      $class = "secondary";
    }
    $primary = !$primary;

    $result .= "
<tr class=\"$class\">
  <td>$name</td>
  <td>$size</td>
  <td>$used</td>
  <td>$avail</td>
  <td>$cap%</td>
  <td>$dir</td>";

  }

  $result .= "</table>";

  return $result;
}

sub showVersion {

  my $xml = shift;

  my $hostName = $xml->{'host-name'}->[0];
  my $productName = $xml->{'product-name'}->[0];

  my $result = "
      <table class=\"no-border\">
        <tr class=\"title\"><td>Name</td><td>Info</td></tr>
        <tr class=\"primary\"><td>Hostname</td><td>$hostName</td></tr>
        <tr class=\"secondary\"><td>Model</td><td>$productName</td></tr>";

  my $software = $xml->{'package-information'};

  my $primary = 1;

  for ($i = 0; $i < @$software; $i++) {

    my $item = $software->[$i];
    my $name = $item->{'name'}->[0];
    my $desc = $item->{'comment'}->[0];
    my $class;

    if ($primary) {
      $class = "primary";
    }
    else {
      $class = "secondary";
    }

    $primary = !$primary;

    $result .= "
        <tr class=\"$class\"><td>$name</td><td>$desc</td></tr>";
  }

  $result .= "</table>";

  return $result;
}

1;
