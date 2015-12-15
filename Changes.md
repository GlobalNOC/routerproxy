## Changes

### Version 1.8.0 - Dec 15 2015
* ISSUE=7386 avoid frontend getting out of sync with configured devices and submitting command to wrong device
* ISSUE=11786 disable strict host key checking / user known hosts file
* ISSUE=12546 remove Net::SSH::Perl support

### Version 1.7.6 - Mar 28 2014
* ISSUE=7928 fix issue where # or > characters in the login banner for JunOS would confuse logins
* ISSUE=7639 fix issue when sending commands to junipers with the ? character where it would timeout due to not failing to match the command prompt
* ISSUE=6696 fix issue with location data displaying hashes
* ISSUE=5472 rpm now installs .ssh directory so there will be no permissions conflict

### Version 1.7.5 - Dec 13 2012
* ISSUE=4368 Added support for configurable command help text

### Version 1.7.4 - Oct 5 2012
* ISSUE=2229 Improve RPM with mappable configuration file, change configuration file path, update README.
* ISSUE=4425 PROJ=102 Add a config variable to enable/disable the appearance of menu commands

### Version 1.7.3 - Nov 17 2011
* ISSUE=2919 PROJ=102 added support for brocade devices

### Version 1.7.2 - May 25 2011
* ISSUE=2100 PROJ=102 implement collapsable menu titles

### Version 1.7.1 - May 2 2011
* ISSUE=2206 PROJ=102 Added ability to have <exclude> elements at the same level as <command>

### Version 1.7.0 - Nov 24 2010
* Adding build support for RPM

### Version 1.6.4 - Aug 18 2010
* ISSUE=1171 PROJ=102 use FileHandle before use XML::Simple to fix error in perl 5.10 (thanks Stan Barber @ SETG)

### Version 1.6.3 - Feb 19 2010
* ISSUE=670 PROJ=102 fixed output of JUNOS SNMP Statistics command
* ISSUE=734 PROJ=102 use routerproxy/ dir as home dir to create .ssh/ directory
* ISSUE=733 PROJ=102 fixing issue where perl would die if Cisco::IOS_XR wasn't installed--now it doesn't have to be

### Version 1.6.2 - Feb 9 2010
* Cisco NX-OS support
* added <layer> option to devices to group them rather than using <type>

### Version 1.6.1 - Feb 20 2009 
* security fix to perform extra command validation to prevent circumventing allowed commands

### Version 1.6 - Jul 15 2008
* new GRNOC::TL1 module must be separately installed
* minor bug fixes and uses the new GRNOC::TL1 code

### Version 1.53
* Added some IOS XR (CRS) menu-based commands (requires Cisco IOS XR XML Perl library)

### Version 1.52
* Junoscript no longer necessary (unless you want to use the menu-based commands with tabular output)
* Fixed more alignment/width visualization issues
* Fixed a problem parsing Junoscript XML from some Juniper devices
* Issued command is now echoed in the command output
* Fixed a problem with Juniper & Force10 output not being fully retrieved for some commands
* Error markers (^) now properly align where the syntax error was

### Version 1.51
* IOS Switch 2xxx (ios2) Telnet Support Added
* Router name included in log file
* IE7 CSS drop down menu bug fix
* Tabular alignment improvement
* Added RouterProxy.pm engine junoscript output support
* Fixed Juniper SSH commands that sometimes wouldn't work
* Made the <timeout> option work properly for timing out SSH commands

### Version 1.5
* RouterProxy has been completely rewritten from earlier versions
* Added Force10, TL1, Junoscript, HP support
* Javascript + AJAX Technology
* New Menu-based Commands with tabular output
