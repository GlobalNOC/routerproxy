FROM centos/httpd-24-centos7

USER 0

COPY conf/globalnoc-public-el7.repo /etc/yum.repos.d/globalnoc-public-el7.repo

RUN yum makecache
RUN yum -y install epel-release

RUN yum -y install perl-Template-Toolkit perl-XML-Parser perl-XML-Simple perl-CGI-Ajax perl-Time-ParseDate perl-Net-Telnet perl-Expect perl-GRNOC-TL1 perl-GRNOC-Config perl-Class-Accessor perl-YAML perl-JSON perl-Log-Log4perl
RUN yum -y install perl-GRNOC-WebService perl-GRNOC-WebService-Client perl-Test-Deep perl-Test-Exception perl-Test-Pod perl-Test-Pod-Coverage perl-Devel-Cover perl-Data-Dumper perl-Test-Harness perl-Test-Simple openssh-clients

COPY conf/routerproxy.conf /etc/httpd/conf.d/routerproxy.conf
COPY conf/mappings.xml     /etc/grnoc/routerproxy/mappings.xml
COPY conf/logging.conf     /etc/grnoc/routerproxy/logging.conf
COPY conf/routerproxy.yaml /etc/grnoc/routerproxy/routerproxy.yaml

COPY lib/GRNOC /usr/share/perl5/vendor_perl/GRNOC
COPY templates /usr/share/grnoc/routerproxy/templates
COPY webroot   /usr/share/grnoc/routerproxy/www

RUN mkdir -p /var/log/grnoc/routerproxy
RUN touch /var/log/grnoc/routerproxy/routerproxy.log
RUN chown 1001:1001 /var/log/grnoc/routerproxy/routerproxy.log

USER 1001

# TODO Make ENTRYPOINT
CMD run-httpd
