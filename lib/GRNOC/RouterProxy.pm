package GRNOC::RouterProxy;
our $VERSION = '2.4.0';

use strict;
use warnings;

use Expect;
use Net::Telnet;
use Log::Log4perl;
use Data::Dumper;

use GRNOC::Config;
use GRNOC::TL1;
use GRNOC::TL1::Device::Nortel::OME6500;
use GRNOC::TL1::Device::Nortel::HDXc;
use GRNOC::TL1::Device::Cisco::ONS15454;
use GRNOC::TL1::Device::Ciena::CoreDirector;

use GRNOC::RouterProxy::Config;

my $timeout = 0;
my $hasJunoscript;

Log::Log4perl::init('/etc/grnoc/routerproxy/logging.conf');
my $logger = Log::Log4perl->get_logger('GRNOC.RouterProxy');

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


sub new {
    my $caller = shift;
    my $class = ref($caller) || $caller;

    my $self = {
        username   => 'username',
        password   => 'password',
        type       => 'junos',
        method     => 'ssh',
        junoscript => '0',
        iosxml     => '0',
        hostname   => 'hostname',
        port       => '23',
        maxlines   => '5000',
        timeout    => '60',
        debug      => '0',
        @_
    };

  bless($self, $class);
  return $self;
}


#ISSUE=12307 Remove sensitive information, as specified in the config file, from any output
sub sanitize_text {
    my $self = shift;
    my $text = shift;

    my $conf = GRNOC::RouterProxy::Config->new($self->{'config_path'});
    my $stanzas = $conf->Redacts();

    foreach my $stanza ( @$stanzas ) {
        $stanza =~ s/ /&nbsp\;/g;
        $stanza =~ s/(?<!\?)</&lt\;/g;
        $stanza =~ s/>/&gt\;/g;
        $text =~ s/$stanza/\[REDACTED\]/g;
    }
    return $text;
}


# Helper to swap chars for HTML codes and sanitize result strings
sub clean_result {
    my $self     = shift;
    my $result   = shift;
    my $sanitize = shift || 1;
    $result =~ s/ /&nbsp;/g;
    $result =~ s/</&lt;/g;
    $result =~ s/>/&gt;/g;
    $result = $self->sanitize_text($result) if $sanitize;
    return $result
}


sub blankPrompt {
     my $string = shift;

    # pull out the first line
    my $line = substr($string, 0, index($string, "\n"));

    # find the first >
    my $index = index($line, '>');

    # otherwise find the first #
    $index = index($line, '#') if ($index < 0);

    # get the prompt (user at host)
    my $prompt = substr($string, 0, $index + 1);

    # replace each char with a space
    $prompt =~ s/#/>/;
    $prompt =~ s/[^>]/\./g;

    # get everything after the prompt
    $string = substr($string, $index + 1);

    # reattach our blanked out prompt to the rest of the string
    $string = $prompt . $string;

    return $string;
}


sub command {
    my ($self) = @_;
    shift;
    my $command = shift;

    $logger->info("Issuing command '$command' on $self->{'hostname'}");

    if ($self->{'type'} eq "ome" || $self->{'type'} eq "hdxc" || $self->{'type'} eq "ons15454"  || $self->{'type'} eq "ciena") {
        my $tl1 = GRNOC::TL1->new(
            username => $self->{'username'},
            password => $self->{'password'},
            type     => $self->{'type'},
            host     => $self->{'hostname'},
            port     => $self->{'port'},
            ctag     => 1337
        );
        $tl1->connect();
        $tl1->login();

        my $result = $tl1->cmd($command);
        return $self->clean_result($result);
    }

    elsif ($self->{'type'} eq "iosxr" && $self->{'method'} eq "ssh") {
        my $result = &iosxrSSH($self, $command);
        return $self->clean_result($result, 0);
    }

    elsif ($self->{'type'} eq "hp" && $self->{'method'} eq "ssh") {
        my $result = &hpSSH($self, $command);
        return $self->clean_result($result);
    }

    elsif (($self->{'type'} eq "ios2" || $self->{'type'} eq "ios" || $self->{'type'} eq "ios6509" || $self->{'type'} eq "nx-os" || $self->{'type'} eq 'brocade') && $self->{'method'} eq "ssh") {
        my $result = &ios2SSH($self, $command);
        return $self->clean_result($result);
    }

    elsif ($self->{'type'} eq "ios2" && $self->{'method'} eq "telnet") {
        my $result = &ios2Telnet($self, $command);
        return $self->clean_result($result);
    }

    elsif ($self->{'type'} eq "force10" && $self->{'method'} eq "ssh") {
        my $result = &force10SSH($self, $command);
        return $self->clean_result($result);
    }

    elsif ($self->{'type'} eq "bladeOS" && $self->{'method'} eq "ssh") {
        my $result = &bladeOS($self, $command);
        return $self->clean_result($result);
    }
  
    elsif ($self->{'type'} eq "junos" && $self->{'method'} eq "ssh") {
        my $result = &junosSSH($self, $command);
        return $self->clean_result($result);
    }

    elsif ($self->{'type'} eq "arista" && $self->{'method'} eq "ssh") {
        my $result = &aristaSSH($self, $command);
        return $self->clean_result($result, 0);
    }

    elsif ($self->{'method'} eq "ssh") {
        return "Unsupported connection type" if ($self->{'junoscript'} ne "1");

        my $result;
        if (!$hasJunoscript) {
            $result = "Junoscript must be installed";
        }
        else {
            my %info = (
                access   => "ssh",
                login    => $self->{'username'},
                password => $self->{'password'},
                hostname => $self->{'hostname'}
            );
            my $junos = new JUNOS::Device(%info);
            $result = $junos->command($command)->toString;
            $result =~ s/junos://g;
        }
        $result = $self->sanitize_text($result);
        return $result;
    }

    elsif ($self->{'method'} eq "telnet") {
        my $buf;
        my $prompt;

        my $port = $self->{'port'} || "23"; # Default port 23
        my $telnet = Net::Telnet->new(
            Timeout => 1,
            Errmode => 'return',
            Port => $port
        );
        my $result = $telnet->open($self->{'hostname'});
        die($telnet->errmsg()) unless $result;

        # JunOS login
        if ($self->{'type'} eq "junos") {
            if ($self->{'junoscript'} eq "1") {
                if (!$hasJunoscript) {
                    $result = "Junoscript must be installed";
                }
                else {
                    my %info = (
                        access   => "telnet",
                        login    => $self->{'username'},
                        password => $self->{'password'},
                        hostname => $self->{'hostname'}
                    );
                    my $junos = new JUNOS::Device(%info);
                    my $result = $junos->command($command)->toString;
                    $result =~ s/junos://g;
                }
                $result = $self->sanitize_text($result);
                return $result;
            }
            else {
                my $result = $telnet->login($self->{'username'}, $self->{'password'});
                die($telnet->errmsg()) unless ($result);
                $telnet->cmd("set cli screen-length 0");
            }
        }

        # IOS login
        elsif ($self->{'type'} eq "ios" || $self->{'type'} eq "ios6509") {
            $telnet->login($self->{'username'}, $self->{'password'});
            die($telnet->errmsg()) unless ($result);
            $telnet->cmd("terminal length 0");
        }

        eval {
            # setup the timeout handler
            local $SIG{'ALRM'} = sub {
                $buf .= "\n--- Maximum Timeout Exceeded ---\n";
                die;
            };

            # start the timeout timer
            alarm($self->{'timeout'});

            # issue command and eat up echo
            $telnet->print($command);
            $telnet->getline();

            # eat up extra lines for IOS
            if ($self->{'type'} eq "ios") {
                $telnet->getline();
                $telnet->getline();
                $telnet->getline();
            }

            my $i = 0;
            my $msg;
            while (1) {
                $msg = $telnet->getline();
                last if ($msg eq "");
                # $msg =~ s/ /&nbsp;/g;
                # $msg =~ s/</&lt;/g;
                # $msg =~ s/>/&gt;/g;
                $msg = $self->clean_result($msg, 0);
                $buf .= $msg;
                $i++;
                if ($i == $self->{'maxlines'}) {
                    $buf .= "\n--- Maximum Output Exceeded ---\n";
                    last;
                }
            }
            alarm(0);
        };

        $buf = $self->sanitize_text($buf);
        return $buf;
    }
}


sub force10SSH {
    my $self = shift;
    my $cmd  = shift;

    my $username = $self->{'username'};
    my $password = $self->{'password'};
    my $hostname = $self->{'hostname'};

    my $prompt;
    my $buf;
    my $count = 0;
    my $ssh;

    $ssh = Expect->spawn("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l $username $hostname");
    $ssh->log_stdout(0);
    $ssh->log_file(sub {$prompt .= shift });
    $ssh->expect(
        $self->{'timeout'},
        [
            'assword:',
            sub {
                my $out = shift;
                print $out "$password\n";
                exp_continue;
            }
        ],
        [
            'yes/no',
            sub {
                my $out = shift;
                print $out "yes\n";
                exp_continue;
            }
        ],
        ['#', sub {}],
        ['>', sub {}]
    );

    $prompt = reverse($prompt);
    my $index = index($prompt, "\n");
    $prompt = reverse(substr($prompt, 0, $index));

    $ssh->log_file(sub { $buf .= shift });
    $ssh->send("terminal length 0\r\n");
    $ssh->expect($self->{'timeout'}, ["^$prompt", sub {}]);

    eval {
        local $SIG{'ALRM'} = sub {
            $buf .= "\n--- Maximum Timeout Exceeded ---\n\n";
            die;
        };

        $ssh->log_file(sub {
            if ($count >= $self->{'maxlines'}) {
                $buf .= "\n--- Maximum Output Exceeded ---\n\n";
                $ssh->log_file(undef);
                die;
            }
            my $data = shift;
            $buf .= $data;
            my $newlines = ($data =~ tr/\n//);
            $count += $newlines;
        });
        alarm($self->{'timeout'});

        # dont give a newline if the command contains ?
        my $matchCmd = $cmd;
        if ($cmd =~ /\?/) {
            chop($matchCmd);
            $ssh->send("$cmd");
        }
        else {
            $ssh->send("$cmd\r\n");
        }
        $ssh->expect($self->{'timeout'}, ["^$prompt", sub {}]);
        alarm(0);
    };

    $buf =~ s/.*\n//;
    $buf = blankPrompt($buf);
    $buf = reverse($buf);
    $buf =~ s/.*\n//;
    $buf = reverse($buf);
    return $buf;
}


sub bladeOS {
    my $self = shift;
    my $cmd  = shift;

    my $username = $self->{'username'};
    my $password = $self->{'password'};
    my $hostname = $self->{'hostname'};

    my $prompt;
    my $buf;
    my $count = 0;
    my $ssh;

    $ssh = Expect->spawn("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l $username $hostname");
    $ssh->log_stdout(0);
    $ssh->log_file(sub {$prompt .= shift });
    $ssh->expect(
        $self->{'timeout'},
        [
            'assword:',
            sub {
                my $out = shift;
                print $out "$password\n";
                exp_continue;
            }
        ],
        [
            'yes/no',
            sub {
                my $out = shift;
                print $out "yes\n";
                exp_continue;
            }
        ],
        ['#', sub {}],
        ['>', sub {}]
    );

    $prompt = reverse($prompt);
    my $index = index($prompt, "\n");
    $prompt = reverse(substr($prompt, 0, $index));

    $ssh->log_file(sub { $buf .= shift });
    $ssh->send("terminal length 0\r\n");
    $ssh->expect($self->{'timeout'}, ["^$prompt", sub {}]);

    eval {
        local $SIG{'ALRM'} = sub {
            $buf .= "\n--- Maximum Timeout Exceeded ---\n\n";
            die;
        };

        $ssh->log_file(sub {
            if ($count >= $self->{'maxlines'}) {
                $buf .= "\n--- Maximum Output Exceeded ---\n\n";
                $ssh->log_file(undef);
                die;
            }
            my $data = shift;
            $buf .= $data;
            my $newlines = ($data =~ tr/\n//);
            $count += $newlines;
        });
        alarm($self->{'timeout'});

        # dont give a newline if the command contains ?
        my $matchCmd = $cmd;
        if ($cmd =~ /\?/) {
            chop($matchCmd);
            $ssh->send("$cmd");
        }
        else {
            $ssh->send("$cmd\r\n");
        }
        $ssh->expect($self->{'timeout'},["^$prompt",sub {}]);
        alarm(0);
    };

    # remove 4 blank lines
    $buf =~ s/.*\n//;
    $buf =~ s/.*\n//;
    $buf =~ s/.*\n//;
    $buf =~ s/.*\n//;    
    $buf = reverse($buf);
    #remove last line (prompt)
    $buf =~ s/.*\n//;
    $buf = reverse($buf);
    return $buf;
}


sub hpSSH {
    my $self = shift;
    my $cmd  = shift;

    my $username = $self->{'username'};
    my $password = $self->{'password'};
    my $hostname = $self->{'hostname'};

    my $buf;
    my $count = 0;
    my $ssh;

    $ssh = Expect->spawn("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l $username $hostname");
    $ssh->log_stdout(0);
    $ssh->expect(
        $self->{'timeout'},
        [
            'assword:',
            sub {
                my $out = shift;
                print $out "$password\n";
                exp_continue;
            }
        ],
        [   'Press any key to continue',
            sub {
                my $out = shift;
                print $out "\n";
                exp_continue;
            }
        ],
        [   'yes/no',
            sub {
                my $out = shift;
                print $out "yes\n";
                exp_continue;
            }
        ],
        ['#', sub {}],
        ['>', sub {}]
    );

    my $questionMark = 0;
    eval {
        local $SIG{'ALRM'} = sub {
            $buf .= "\n--- Maximum Timeout Exceeded ---\n\n";
            die;
        };

        $ssh->log_file(sub {
            if ($count >= $self->{'maxlines'}) {
                $ssh->log_file(undef);
                $buf .= "\n--- Maximum Output Exceeded ---\n\n";
                die;
            }
            my $data = shift;
            $data =~ s/-- MORE --.*Control-C.*$//;
            $data =~ s/\e[[\w;]*//g;
            $buf .= $data;

            my $newlines = ($data =~ tr/\n//);
            $count += $newlines;
        });
        alarm($self->{'timeout'});

        if ($cmd =~ /\?/) {
            $questionMark = 1;
            $cmd =~ s/(.*)\?/$1/;
            $ssh->send("$cmd");
            sleep(1);
            $ssh->send("?");
        }
        else {
            $ssh->send("$cmd\n");
        }
        $ssh->expect(
            $self->{'timeout'},
            ['[>]', sub {}],
            [
                'Control-C',
                sub {
                    my $out = shift;
                    print $out " ";
                    exp_continue;
                }
            ]
        );
        alarm(0);
    };

    # detect invalid input and fix it
    if ($buf =~ /input: (.*)/) {
        $buf = "Invalid input: $1";
        return $buf;
    }
    $buf =~ s/.*\n//;

    # create dummy prompt
    if ($questionMark) {
        $buf = "> $cmd?\n" . $buf;
    }
    else {
        $buf = "> $cmd\n" . $buf;
    }

    $buf = reverse($buf);
    # remove last line (prompt)
    $buf =~ s/.*\n//;
    $buf = reverse($buf);
    return $buf;
}


sub ios2Telnet {
    my $self = shift;
    my $cmd = shift;

    my $username = $self->{'username'};
    my $password = $self->{'password'};
    my $hostname = $self->{'hostname'};

    my $buf;
    my $count = 0;
    my $telnet;

    $telnet = Net::Telnet->new(Timeout => 1, Errmode => 'return', Port => $self->{'port'});
    my $result = $telnet->open($self->{'hostname'});
    die($telnet->errmsg()) unless ($result);

    $telnet->login($username, $password);
    $telnet->cmd("terminal length 0");
    $telnet->buffer_empty();

    eval {
        # setup the timeout handler
        local $SIG{'ALRM'} = sub {
            $buf .= "\n--- Maximum Timeout Exceeded ---\n";
            die;
        };

        # start the timeout timer
        alarm($self->{'timeout'});

        # issue command and eat up echo
        $telnet->print($cmd);
        $telnet->getline();

        # eat up extra lines for IOS
        if ($self->{'type'} eq "ios") {
        $telnet->getline();
        $telnet->getline();
        $telnet->getline();
        }

        my $i = 0;
        my $msg;
        while (1) {
            $msg = $telnet->getline();
            last if ($msg eq "");
            $buf .= $msg;
            $i++;
            if ($i == $self->{'maxlines'}) {
                $buf .= "\n--- Maximum Output Exceeded ---\n";
                last;
            }
        }
        alarm(0);
    };
    return $buf;
}


sub ios2SSH {
    my $self = shift;
    my $cmd  = shift;

    my $username = $self->{'username'};
    my $password = $self->{'password'};
    my $hostname = $self->{'hostname'};

    my $buf;
    my $count = 0;
    my $ssh;

    $ssh = Expect->spawn("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l $username $hostname");
    $ssh->log_stdout(0);
    $ssh->expect(
        5,
        [
            'assword:',
            sub {
                my $out = shift;
                print $out "$password\n";
                exp_continue;
            }
        ],
        [
            'yes/no',
            sub {
                my $out = shift;
                print $out "yes\n";
                exp_continue;
            }
        ],
        ['#', sub {}],
        ['>', sub {}]
    );

    $ssh->log_file(sub { $buf .= shift });
    $ssh->send("terminal length 0\n");
    $ssh->expect(
        5,
        ['#', sub {}],
        ['>', sub {}]
    );

    eval {
        local $SIG{'ALRM'} = sub {
            $buf .= "\n--- Maximum Timeout Exceeded ---\n\n";
            die;
        };

        $ssh->log_file(sub {
            if ($count >= $self->{'maxlines'}) {
                $ssh->log_file(undef);
                $buf .= "\n--- Maximum Output Exceeded ---\n\n";
                die;
            }
            my $data = shift;
            $buf .= $data;

            my $newlines = ($data =~ tr/\n//);
            $count += $newlines;
        });
        alarm($self->{'timeout'});

        if ($cmd =~ /\?/) {
            $ssh->send("$cmd");
        }
        else {
            $ssh->send("$cmd\n");
        }
        $ssh->expect(
            $self->{'timeout'},
            ['^\S*#', sub {}],
            ['^\S*>', sub {}]
        );
        alarm(0);
    };

    $buf =~ s/.*\n//;
    $buf =~ s/.*\n//;
    $buf = blankPrompt($buf);
    $buf = reverse($buf);
    # remove last line (prompt)
    $buf =~ s/.*\n//;
    $buf = reverse($buf);
    return $buf;
}


sub iosxrSSH {
    my $self = shift;
    my $cmd  = shift;

    my $username = $self->{'username'};
    my $password = $self->{'password'};
    my $hostname = $self->{'hostname'};

    my $buf;
    my $count = 0;
    my $questionMark = 0;
    my $ssh;
    $ssh = Expect->spawn("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l $username $hostname");
    $ssh->log_stdout(0);
    $ssh->expect(
        $self->{'timeout'},
        [
            'assword:',
            sub {
                my $out = shift;
                print $out "$password\n";
                exp_continue;
            }
        ],
        [
            'yes/no',
            sub {
                my $out = shift;
                print $out "yes\n";
                exp_continue;
            }
        ],
        ['#', sub {}],
        ['>', sub {}]
    );

    $ssh->log_file(sub { $buf .= shift });
    $ssh->send("terminal length 0\n");
    $ssh->expect(
        $self->{'timeout'},
        ['#', sub {}],
        ['>', sub {}]
    );

    eval {
        local $SIG{'ALRM'} = sub {
            $buf .= "\n--- Maximum Timeout Exceeded ---\n\n";
            die;
        };
        alarm($self->{'timeout'});

        if ($cmd =~ /\?/) {
            $questionMark = 1;
            $ssh->send("$cmd");
        }
        else {
            $ssh->send("$cmd\n");
        }

        $ssh->log_file(sub {
            if ($count >= $self->{'maxlines'}) {
                $ssh->log_file(undef);
                $buf .= "\n--- Maximum Output Exceeded ---\n\n";
                die;
            }
            my $data = shift;
            $buf .= $data;
            my $newlines = ($data =~ tr/\n//);
            $count += $newlines;
        });

        if ($questionMark) {
            $cmd =~ s/(.*)\?/$1/;
            $ssh->expect(
                $self->{'timeout'},
                ["^.*[#>]($cmd)", sub {}]
            );
        }
        else {
            $ssh->expect(
                $self->{'timeout'},
                ['^.*#$', sub {}],
                ['^.*>$', sub {}]
            );
        }
        alarm(0);
    };

    # remove first blank line
    $buf =~ s/.*\n//;
    $buf = blankPrompt($buf);

    # add an extra space to line up the ^ if needed
    $buf =~ s/\^/ ^/ if ($buf =~ /% Invalid input detected at/);

    $buf = reverse($buf);
    #remove last line (prompt)
    $buf =~ s/.*\n//;
    $buf = reverse($buf);
    return $buf;
}


sub junosSSH {
    my $self = shift;
    my $cmd  = shift;

    my $username = $self->{'username'};
    my $password = $self->{'password'};
    my $hostname = $self->{'hostname'};

    my $buf;
    my $count = 0;
    my $ssh;
    my $questionMark = 0;

    $ssh = Expect->spawn("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l $username $hostname");
    $ssh->log_stdout(0);
    $ssh->expect(
        $self->{'timeout'},
        [
            'assword:',
            sub {
                my $out = shift;
                print $out "$password\n";
            }
        ],
        [
            'yes/no',
            sub {
                my $out = shift;
                print $out "yes\n";
                exp_continue;
            }
        ]
    );

    $ssh->expect(
        $self->{'timeout'},
        ['^([^\\s])*#\\\s\$', sub {}],
        ['^([^\\s])*>\\\s\$', sub {}]
    );

    $ssh->log_file(sub { $buf .= shift });
    $ssh->send("set cli screen-length 0\n");
    
    $ssh->expect(
        $self->{'timeout'},
        ['^([^\\s])*#\\\s\$', sub {}],
        ['^([^\\s])*>\\\s\$', sub {}]
    );
  
    eval {
        local $SIG{'ALRM'} = sub {
            $buf .= "\n--- Maximum Timeout Exceeded ---\n\n";
            die;
        };
        $ssh->log_file(sub {
            if ($count >= $self->{'maxlines'}) {
                $ssh->log_file(undef);
                $buf .= "\n--- Maximum Output Exceeded ---\n\n";
                die;
            }
            my $data = shift;
            $buf .= $data;
            my $newlines = ($data =~ tr/\n//);
            $count += $newlines;
        });
        alarm($self->{'timeout'});

        if ($cmd =~ /\?/) {
            $questionMark = 1;
            $ssh->send("$cmd");
        }
        else {
            $ssh->send("$cmd\n");
        }

        if ($questionMark) {
            $cmd =~ s/(.*)\?/$1/;
            $ssh->expect(
                $self->{'timeout'},
                ["^.*# $cmd", sub {}],
                ["^.*> $cmd", sub {}]
            );
        }
        else {
            $ssh->expect(
                $self->{'timeout'},
                ['^([^\\s])*#\\\s\$', sub {}],
                ['^([^\\s])*>\\\s\$', sub {}]
            );
        }
        alarm(0);
    };

    # remove first 3 lines
    $buf =~ s/.*\n//;
    $buf =~ s/.*\n//;
    $buf =~ s/.*\n//;
    if ($buf =~ /{.*}.*\n/) {
        $buf =~ s/.*\n//;
    }

    # blank out the prompt on the first line
    $buf = blankPrompt($buf);
    $buf = reverse($buf);
    # remove last line (prompt)
    $buf =~ s/.*\n//;
    $buf =~ s/.*\n// if ($buf =~ /}.*{.*\n/);

    if ($questionMark) {
        my $check = reverse("syntax error, expecting");
        if ($buf =~ /$check/) {
            $buf =~ s/.*\n//;
            $buf =~ s/.*\n//;
            $buf =~ s/.*\n//;
            $buf =~ s/.*\n//;
            if ($buf =~ /}.*{.*\n/) {
                $buf =~ s/.*\n//;
            }
        }
    }
    $buf = reverse($buf);
    return $buf;
}


sub aristaSSH {
    my $self = shift;
    my $cmd  = shift;

    my $username = $self->{'username'};
    my $password = $self->{'password'};
    my $hostname = $self->{'hostname'};

    my $buf;
    my $count = 0;
    my $questionMark = 0;
    my $ssh;

    $ssh = Expect->spawn("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l $username $hostname");
    $ssh->log_stdout(0);
    $ssh->expect(
        $self->{'timeout'},
        [
            'assword:',
            sub {
                my $out = shift;
                print $out "$password\n";
                exp_continue;
            }
        ],
        [
            'yes/no',
            sub {
                my $out = shift;
                print $out "yes\n";
                exp_continue;
            }
        ],
        ['#', sub {}],
        ['>', sub {}]
    );

    $ssh->log_file(sub { $buf .= shift });
    $ssh->send("terminal length 0\n");
    $ssh->expect(
        $self->{'timeout'},
        ['#', sub {}],
        ['>', sub {}]
    );

    eval {
        local $SIG{'ALRM'} = sub {
            $buf .= "\n--- Maximum Timeout Exceeded ---\n\n";
            die;
        };
        alarm($self->{'timeout'});

        if ($cmd =~ /\?/) {
            $questionMark = 1;
            $ssh->send("$cmd");
        }
        else {
            $ssh->send("$cmd\n");
        }

        $ssh->log_file(sub {
            if ($count >= $self->{'maxlines'}) {
                $ssh->log_file(undef);
                $buf .= "\n--- Maximum Output Exceeded ---\n\n";
                die;
            }
            my $data = shift;
            $buf .= $data;
            my $newlines = ($data =~ tr/\n//);
            $count += $newlines;
        });

        if ($questionMark) {
            $cmd =~ s/(.*)\?/$1/;
            $ssh->expect(
                $self->{'timeout'},
                ["^.*[#>]($cmd)", sub {}]
            );
        }
        else {
            $ssh->expect(
                $self->{'timeout'},
                ['^.*#$', sub {}],
                ['^.*>$', sub {}]
            );
        }
        alarm(0);
    };

    # remove first blank line
    $buf =~ s/.*\n//;
    $buf = blankPrompt($buf);

    # add an extra space to line up the ^ if needed
    $buf =~ s/\^/ ^/ if ($buf =~ /% Invalid input detected at/);

    $buf = reverse($buf);
    #remove last line (prompt)
    $buf =~ s/.*\n//;
    $buf = reverse($buf);
    return $buf;
}

1;
