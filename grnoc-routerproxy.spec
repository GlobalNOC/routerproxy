Summary: GRNOC Router Proxy
Name: grnoc-routerproxy
Version: 1.7.7
Release: 1%{?dist}
License: GRNOC
Group: Auth
URL: http://globalnoc.iu.edu
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch
Requires: httpd
Requires: openssh-clients
Requires: perl >= 5.8.8
Requires: perl(XML::Parser)
Requires: perl(XML::Simple)
Requires: perl(CGI::Ajax)
Requires: perl(Time::ParseDate)
Requires: perl(Net::Telnet)
Requires: perl(Expect)
Requires: perl(GRNOC::TL1)
Requires: perl(GRNOC::Config)
Requires: perl(Class::Accessor)
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
