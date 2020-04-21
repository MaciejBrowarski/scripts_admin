LN=/bin/ln

all:  install
install:
	test -L "netbone.pl" || $(LN) -s load.pl netbone.pl
	test -L "idscron.pl" || $(LN) -s load.pl idscron.pl
	test -L "agent.pl" || $(LN) -s load.pl agent.pl
	test -L "scripts.pl" || $(LN) -s load.pl scripts.pl
	test -L "scripts_admin.pl" || $(LN) -s load.pl scripts_admin.pl
	test -L "watchdog.pl" || $(LN) -s load.pl watchdog.pl
	test -L "sms.pl" || $(LN) -s load.pl sms.pl
	test -L "www.pl" || $(LN) -s load.pl www.pl
	test -L "language.pm" || $(LN) -s ../scripts/language.pm language.pm
	test -L "report_root.pl" || $(LN) -s report.pl report_root.pl

	test -L "common_cmit.pm" || $(LN) -s ../scripts/common_cmit.pm common_cmit.pm
	test -L "env.pm" || $(LN) -s ../scripts/env.pm env.pm
clean:
	rm netbone.pl idscron.pl agent.pl watchdog.pl sms.pl scripts.pl scripts_admin.pl language.pm report_root.pl common_cmit.pm env.pm www.pl

