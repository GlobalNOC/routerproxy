# GlobalNOC RouterProxy

## Contents
0. About
1. Installation
2. Dependencies
3. TODO
4. Supported Devices
5. Banana

## About
RouterProxy is a web-based perl-driven management tool specifically designed for Cisco,
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

* JUNOS::Device / junoscript (see http://www.juniper.net/support/xml/junoscript/index.html)
(NOTE: This is now only required for the menu based commands.. if you
don't have it installed, RouterProxy will still work).
* CGI
* CGI::Ajax
* XML::Simple
* Encode
* Expect
* Time::ParseDate
* Date::Calc
* GRNOC::TL1

These modules have several dependencies of their own, so make sure they are installed as well.

## TODO
* IOS Menu Commands?
* Force10 Menu Commands?
* HP Menu Commands?
* Telnet support for IOS XR, Force10, HP (currently does not work).

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
* Brocade       brocade

## Banana
🍌
