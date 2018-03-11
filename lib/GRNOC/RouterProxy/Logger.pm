package GRNOC::RouterProxy::Logger;

use Time::ParseDate;

sub addEntry {

  my $logfile = shift;
  my $ip = shift;
  my $router = shift;
  my $cmd = shift;

  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
  $year += 1900;
  $mon++;

  if ($hour < 10) {
    $hour = "0$hour";
  }
  if ($min < 10) {
    $min = "0$min";
  }
  if ($sec < 10) {
    $sec = "0$sec";
  }

  my $time = "[$year/$mon/$mday $hour:$min:$sec]";

  open(FILE, ">>$logfile") || die ("Error opening log file");
  print FILE "$time $ip $router: $cmd\n";
  close(FILE);
}

sub getLastTime {

  my $logfile = shift;
  open(FILE, $logfile);
  my @lines = <FILE>;
  close(FILE);

  my $lastLine = $lines[@lines - 1];
  my ($year, $month, $day, $hour, $min, $sec) = $lastLine =~ /\[([^\/]*)\/([^\/]*)\/([^ ]*) ([^:]*):([^:]*):([^\]]*).*/;
  #$month++;

  if ($hour < 10) {
    $hour = "0" . $hour;
  }
  if ($min < 10) {
    $min = "0" . $min;
  }
  if ($sec < 10) {
    $sec = "0" . $sec;
  }

  return parsedate("$month-$day-$year $hour:$min:$sec");
}

1;
