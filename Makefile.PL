use strict;
use warnings;
use ExtUtils::MakeMaker;
use FindBin;


WriteMakefile(
    NAME                => 'grnoc-routerproxy',
    AUTHOR              => 'GRNOC Software Engineering <globalnoc@iu.edu>',
    VERSION_FROM        => 'lib/RouterProxy.pm',
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

rpm:    manifest dist
	rpmbuild -ta grnoc-routerproxy-$(VERSION).tar.gz

END
