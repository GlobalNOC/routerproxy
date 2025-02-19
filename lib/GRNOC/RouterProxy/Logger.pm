package GRNOC::RouterProxy::Logger;

use Time::ParseDate;

sub addEntry {
    my ($logfile, $ip, $router, $cmd) = @_;

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
    $year += 1900;
    $mon++;
    $hour = "0$hour" if ($hour < 10);
    $min  = "0$min" if ($min < 10);
    $sec  = "0$sec" if ($sec < 10);

    my $time = "[$year/$mon/$mday $hour:$min:$sec]";

    open(FILE, ">>$logfile") || die ("ERROR: Could not open logfile '$logfile'");
        print FILE "$time $ip $router: $cmd\n";
    close(FILE);
}

sub getLastTime {
    my $logfile = shift;

    open(FILE, $logfile);
        my @lines = <FILE>;
    close(FILE);

    my $lastLine = $lines[@lines - 1];
    return undef unless $lastLine;

    my ($year, $month, $day, $hour, $min, $sec) = $lastLine =~ /\[([^\/]*)\/([^\/]*)\/([^ ]*) ([^:]*):([^:]*):([^\]]*).*/;
    $hour = "0$hour" if ($hour < 10);
    $min  = "0$min" if ($min < 10);
    $sec  = "0$sec" if ($sec < 10);

    return parsedate("$month-$day-$year $hour:$min:$sec");
}

1;
