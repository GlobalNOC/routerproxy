Summary: GRNOC Router Proxy
Name: grnoc-routerproxy
Version: 2.0.1
Release: %{_buildno}%{?dist}
License: GRNOC
Group: Auth
URL: http://globalnoc.iu.edu
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
Requires: httpd
Requires: openssh-clients
Requires: perl >= 5.8.8
Requires: perl-Template-Toolkit
Requires: perl(XML::Parser)
Requires: perl(XML::Simple)
Requires: perl(CGI::Ajax)
Requires: perl(Time::ParseDate)
Requires: perl(Net::Telnet)
Requires: perl(Expect)
Requires: perl(GRNOC::TL1)
Requires: perl(GRNOC::Config)
Requires: perl(Class::Accessor)
Requires: perl(YAML)
Requires: perl(JSON)
Requires: perl(Log::Log4perl)

Provides: perl(GRNOC::RouterProxy)
Provides: perl(GRNOC::RouterProxy::Commands), perl(GRNOC::RouterProxy::Config), perl(GRNOC::RouterProxy::Logger)

BuildRequires: tar
AutoReqProv: no

%description
GRNOC Router Proxy

%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT

%{__install} -d -p                 %{buildroot}%{_sysconfdir}/grnoc/routerproxy/
%{__install} conf/mappings.xml     %{buildroot}%{_sysconfdir}/grnoc/routerproxy/
%{__install} conf/routerproxy.yaml %{buildroot}%{_sysconfdir}/grnoc/routerproxy/
%{__install} conf/logging.conf     %{buildroot}%{_sysconfdir}/grnoc/routerproxy/

%{__install} -d -p %{buildroot}%{_sysconfdir}/httpd/conf.d/grnoc/
%{__install} conf/routerproxy.conf %{buildroot}%{_sysconfdir}/httpd/conf.d/grnoc/

%{__install} -d -p                             %{buildroot}%{perl_vendorlib}/GRNOC/RouterProxy/
%{__install} lib/GRNOC/RouterProxy.pm          %{buildroot}%{perl_vendorlib}/GRNOC/
%{__install} lib/GRNOC/RouterProxy/Commands.pm %{buildroot}%{perl_vendorlib}/GRNOC/RouterProxy/
%{__install} lib/GRNOC/RouterProxy/Config.pm   %{buildroot}%{perl_vendorlib}/GRNOC/RouterProxy/
%{__install} lib/GRNOC/RouterProxy/Logger.pm   %{buildroot}%{perl_vendorlib}/GRNOC/RouterProxy/

%{__install} -d -p                  %{buildroot}%{_datadir}/grnoc/routerproxy/www/
%{__install} webroot/index.cgi      %{buildroot}%{_datadir}/grnoc/routerproxy/www/
%{__install} webroot/style.css      %{buildroot}%{_datadir}/grnoc/routerproxy/www/
%{__install} webroot/routerproxy.js %{buildroot}%{_datadir}/grnoc/routerproxy/www/

%{__install} -d -p              %{buildroot}%{_datadir}/grnoc/routerproxy/templates/
%{__install} templates/index.tt %{buildroot}%{_datadir}/grnoc/routerproxy/templates/

%{__install} -d -p %{buildroot}%{_datadir}/grnoc/routerproxy/.ssh/

%clean
rm -rf $RPM_BUILD_ROOT

%files

%defattr(640,root,apache,-)

%defattr(640,root,apache,-)
%config(noreplace) %{_sysconfdir}/grnoc/routerproxy/mappings.xml
%config(noreplace) %{_sysconfdir}/grnoc/routerproxy/routerproxy.yaml
%config(noreplace) %{_sysconfdir}/grnoc/routerproxy/logging.conf

%defattr(644,root,root,-)
%config(noreplace) %{_sysconfdir}/httpd/conf.d/grnoc/routerproxy.conf

%defattr(644,root,root,-)
%{perl_vendorlib}/GRNOC/RouterProxy.pm
%{perl_vendorlib}/GRNOC/RouterProxy/Commands.pm
%{perl_vendorlib}/GRNOC/RouterProxy/Config.pm
%{perl_vendorlib}/GRNOC/RouterProxy/Logger.pm

%defattr(754,apache,apache,-)
%{_datadir}/grnoc/routerproxy/www/index.cgi
%{_datadir}/grnoc/routerproxy/www/routerproxy.js
%defattr(644,root,apache,-)
%config(noreplace) %{_datadir}/grnoc/routerproxy/www/style.css

%{_datadir}/grnoc/routerproxy/templates/index.tt

%attr(755,apache,apache) %dir %{_datadir}/grnoc/routerproxy/.ssh/
