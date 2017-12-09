FROM debian:stretch

RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN apt-get update
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes apt-utils procps \
        pkg-config gcc g++ make autoconf ctags bison flex libpcre3-dev libxml2-dev libssl-dev \
        git ngrep vim sipsak sip-tester gdb

ENV MYSQL_ROOT_PASSWORD=ktestsrootpw
RUN DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes mysql-client mysql-server default-libmysqlclient-dev
RUN rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
	&& chmod 777 /var/run/mysqld \
	&& find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/' \
	&& echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf
RUN mysql_install_db --user=mysql

COPY kamailio /usr/local/src/kamailio
WORKDIR /usr/local/src/kamailio
RUN make include_modules="db_mysql tls" cfg
RUN make all
RUN make install
WORKDIR src/modules/tls
RUN make install-tls-cert

ENV DBENGINE=MYSQL
ENV DBRWPW=kamailiorw
ENV DBROOTPW=ktestsrootpw

COPY kamailio-tests /usr/local/src/kamailio-tests
WORKDIR /usr/local/src/kamailio-tests

ENTRYPOINT ["/usr/local/src/kamailio-tests/ktestsctl"]
CMD ["-m", "-q", "run"]
