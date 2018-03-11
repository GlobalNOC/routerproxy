use strict;
use warnings;
use ExtUtils::MakeMaker;
use FindBin;


WriteMakefile(
    NAME                => 'grnoc-routerproxy',
    AUTHOR              => 'GRNOC Software Engineering <globalnoc@iu.edu>',
    VERSION_FROM        => 'lib/GRNOC/RouterProxy.pm',
              PL_FILES            => {},
              PREREQ_PM => {
              },
              dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
              clean               => { FILES => 'grnoc-routerproxy-*.gz' },
              );

sub MY::test {
    q(
TEST_VERBOSE=1

test : pure_all
	$(FULLPERL) t/TEST $(TEST_VERBOSE)

test_jenkins : pure_all
	$(FULLPERL) t/TEST $(TEST_VERBOSE) --formatter=TAP::Formatter::Console

);
}

sub MY::postamble { <<'END'; }
BUILD_NUMBER ?= 1

rpm: dist
	rpmbuild -ta grnoc-routerproxy-$(VERSION).tar.gz --define="_buildno ${BUILD_NUMBER}"

END
