# GlobalNOC RouterProxy

## Contents
0. About
1. Installation
2. Dependencies
3. TODO
4. Supported Devices
5. Changes
6. Banana

## About
Router Proxy is a web-based perl-driven management tool specifically designed for Cisco,
Juniper, and several TL1-based devices.  Command output may be retrieved from the remote
device in its raw form, or if supported (Juniper and TL1 devices) an easy to read tabular form
using the available menu commands.  Both telnet and SSH protocols are supported, as well as
JUNOScript for Juniper devices.  Router Proxy requires Javascript to be enabled and utilizes
AJAX technology to send and receive command input/output.

## Installation
*IMPORTANT* First and foremost, you will almost certainly want to configure Apache to have an
alias for each Router Proxy supported pointing to the webroot folder of Router Proxy. 

Router Proxy itself must be configured.  An example configuration file (config.xml) is provided in the
/etc/grnoc/routerproxy/ with instances for every supported device.  Enabled commands are also
specified for every type of device--users may only issue commands with these prefixes.  You
can add or remove commands as you wish.

Starting from version 1.7.4, the location of the configuration file for each Router Proxy
is acquired by mapping with the url using the mappings file named routerproxy_mappings.xml. 
An example is provided in /etc/grnoc/routerproxy/. The absolute paths must be used for the mapping and 
shouldn't be in a web accessible folder for all to see. This would easily allow someone to 
discover all of the passwords to the devices you have configured for your Router Proxy installation.

If you wish to change the appearance of Router Proxy, feel free to edit the webroot/style.css
cascading style sheet to better suit your needs.

## Dependencies
Router Proxy needs an Apache installation with CGI/Perl support.  Additionally the following
Perl modules need to be installed as well (generally easily done with cpan).

* JUNOS::Device (see http://www.juniper.net/support/xml/junoscript/index.html)
(NOTE: This is now only required for the menu based commands.. if you
don't have it installed, RouterProxy will still work)
* CGI
* CGI::Ajax
* XML::Simple
* Encode
* Expect
* Time::ParseDate
* Date::Calc

**NOTE** JUNOS::Device depends upon several modules itself--which can sometimes be fun to try
and install all of them.  In particular, if you have trouble installing Math::GMP make
sure your have libgmp installed, available at: http://www.swox.com/gmp/.

You will also need to manually install the GRNOC::TL1 module, placing it in a proper lib
directory on your machine.

These modules have several dependencies of their own, so make sure they are installed as well.

## TODO
* IOS Menu Commands?
* Force10 Menu Commands?
* HP Menu Commands?
* Telnet support for IOS XR, Force10, HP (currently does not work)

## Supported Devices
The following list of devices is supported by Router Proxy with their corresponding 'type' as
specified in the config.xml file:

* Cisco IOS  	 	    ios			IOS, doesn't work with IOS XR (CRS etc.)
* Cisco IOS 2xxx	    ios2		Use this for C2950 or similar device (layer 2)
* Cisco IOS 6509	    ios6509		Same as ios, shows up as LAN device on webpage
* Cisco IOS XR		    iosxr		use for CRS or 7000+ devices
* Cisco NX-OS		    nx-os               Cisco NX-OS devices
* Cisco ONS 15454	    ons15454		Cisco ONS 15454
* Juniper JUNOS		    junos		Any JunOS device
* Nortel HDXc		    hdxc		
* Nortel OME		    ome
* Ciena Core Director	    ciena		
* HP ProCurve		    hp			Any HP Switch	
* Force10		    force10	


## Changes
[Version 1.7.6]
* ISSUE=7928 fix issue where # or > characters in the login banner for JunOS would confuse logins
* ISSUE=7639 fix issue when sending commands to junipers with the ? character where it would timeout due to not failing to match the command prompt
* ISSUE=6696 fix issue with location data displaying hashes
* ISSUE=5472 rpm now installs .ssh directory so there will be no permissions conflict

[Version 1.7.5]
* ISSUE=4368 Added support for configurable command help text

[Version 1.7.4]
* ISSUE=2229 Improve RPM with mappable configuration file, change configuration file path, update README.
* ISSUE=4425 PROJ=102 Add a config variable to enable/disable the appearance of menu commands

[Version 1.7.3]
* ISSUE=2919 PROJ=102 added support for brocade devices

[Version 1.7.2]
* ISSUE=2100 PROJ=102 implement collapsable menu titles

[Version 1.7.1]
* ISSUE=2206 PROJ=102 Added ability to have <exclude> elements at the same level as <command>

[Version 1.7.0]
* Adding build support for RPM

[Version 1.6.4]
* ISSUE=1171 PROJ=102 use FileHandle before use XML::Simple to fix error in perl 5.10 (thanks Stan Barber @ SETG)

[Version 1.6.3]
* ISSUE=670 PROJ=102 fixed output of JUNOS SNMP Statistics command
* ISSUE=734 PROJ=102 use routerproxy/ dir as home dir to create .ssh/ directory
* ISSUE=733 PROJ=102 fixing issue where perl would die if Cisco::IOS_XR wasn't installed--now it doesn't have to be

[Version 1.6.2]
* Cisco NX-OS support
* added <layer> option to devices to group them rather than using <type>

[Version 1.6.1]
* security fix to perform extra command validation to prevent circumventing allowed commands

[Version 1.6]
* new GRNOC::TL1 module must be separately installed
* minor bug fixes and uses the new GRNOC::TL1 code

[Version 1.53]
* Added some IOS XR (CRS) menu-based commands (requires Cisco IOS XR XML Perl library)

[Version 1.52]
* Junoscript no longer necessary (unless you want to use the menu-based commands with tabular output)
* Fixed more alignment/width visualization issues
* Fixed a problem parsing Junoscript XML from some Juniper devices
* Issued command is now echoed in the command output
* Fixed a problem with Juniper & Force10 output not being fully retrieved for some commands
* Error markers (^) now properly align where the syntax error was

[Version 1.51]
* IOS Switch 2xxx (ios2) Telnet Support Added
* Router name included in log file
* IE7 CSS drop down menu bug fix
* Tabular alignment improvement
* Added RouterProxy.pm engine junoscript output support
* Fixed Juniper SSH commands that sometimes wouldn't work
* Made the <timeout> option work properly for timing out SSH commands

[Version 1.5]
* RouterProxy has been completely rewritten from earlier versions
* Added Force10, TL1, Junoscript, HP support
* Javascript + AJAX Technology
* New Menu-based Commands with tabular output

## Banana
🍌
