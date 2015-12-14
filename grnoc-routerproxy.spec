Summary: GRNOC Router Proxy
Name: grnoc-routerproxy
Version: 1.7.6
Release: 1%{?dist}
License: GRNOC
Group: Auth
URL: http://globalnoc.iu.edu
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
Requires: httpd >= 2.2.3
Requires: perl >= 5.8.8
Requires: perl-XML-Parser >= 2.34
Requires: perl-XML-Simple >= 2.14
Requires: perl-CGI-Ajax >= 0.707
Requires: perl-Time-modules >= 2003.1126re
Requires: perl-Net-SSH-Perl >= 1.34
Requires: perl-Net-Telnet >= 3.03
Requires: perl-Expect >= 1.21
Requires: perl-GRNOC-TL1 >= 1.2.10
Requires: perl-GRNOC-Config
Requires: perl-Class-Accessor
BuildRequires: tar
AutoReqProv: no

%description
GRNOC Router Proxy

%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT
%{__install} -d -p %{buildroot}/etc/grnoc/routerproxy/
%{__install} conf/config.xml %{buildroot}/etc/grnoc/routerproxy/
%{__install} conf/routerproxy_mappings.xml %{buildroot}/etc/grnoc/routerproxy/
%{__install} -d -p %{buildroot}/etc/httpd/conf.d/grnoc/
%{__install} conf/apache/routerproxy.conf %{buildroot}/etc/httpd/conf.d/grnoc/routerproxy.conf
%{__install} -d -p %{buildroot}/gnoc/routerproxy/lib/
%{__install} -d -p %{buildroot}/gnoc/routerproxy/webroot/
%{__install} -d -p %{buildroot}/gnoc/routerproxy/.ssh/
%{__install} lib/Commands.pm %{buildroot}/gnoc/routerproxy/lib/
%{__install} lib/Logger.pm %{buildroot}/gnoc/routerproxy/lib/
%{__install} lib/RouterProxy.pm %{buildroot}/gnoc/routerproxy/lib/
%{__install} webroot/index.cgi %{buildroot}/gnoc/routerproxy/webroot/
%{__install} webroot/style.css %{buildroot}/gnoc/routerproxy/webroot/
%{__install} README.md %{buildroot}/gnoc/routerproxy/

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(640,root,apache,-)
%defattr(644,root,root,-)
/gnoc/routerproxy/lib/Commands.pm
/gnoc/routerproxy/lib/Logger.pm
/gnoc/routerproxy/lib/RouterProxy.pm
%defattr(754,apache,apache,-)
/gnoc/routerproxy/webroot/index.cgi
%defattr(644,root,apache,-)
%config(noreplace) /gnoc/routerproxy/webroot/style.css
%defattr(640,root,apache,-)
%config(noreplace) /etc/grnoc/routerproxy/config.xml
%config(noreplace) /etc/grnoc/routerproxy/routerproxy_mappings.xml
%defattr(644,root,root,-)
%config(noreplace) /etc/httpd/conf.d/grnoc/routerproxy.conf
/gnoc/routerproxy/README.md
%attr(755,apache,apache) %dir /gnoc/routerproxy/.ssh/

%changelog
* Fri Dec 14 2012 Pairoj Rattadilok <prattadi@grnoc.iu.edu> - 1.7.5-1
- ISSUE=4368 Added support for configurable command help text

* Fri Oct 5 2012 Pairoj Rattadilok <prattadi@grnoc.iu.edu> - 1.7.4-1
- ISSUE=2229 Improve RPM with mappable configuration file, change configuration file path, update README.
- ISSUE=4425 Added configuration variable to enable the display of menu commands.

* Mon May 2  2011 Dan Doyle <daldoyle@grnoc.iu.edu> - 1.7.1-1
- Added ability to have <exclude> elements at the same level as <command>

* Wed Nov 24 2010 Mitch McCracken <mrmccrac@grnoc.iu.edu> - 1.7.0-3
- Include DirectoryIndex options in example Apache config

* Wed Nov 24 2010 Mitch McCracken <mrmccrac@grnoc.iu.edu> - 1.7.0-2
- Include AddHandler options in example Apache config

* Wed Nov 24 2010 Mitch McCracken <mrmccrac@grnoc.iu.edu> - 1.7.0-1
- First RPM-based release
