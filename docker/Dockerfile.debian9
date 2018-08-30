FROM debian:stretch

RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes apt-utils \
  autoconf gcc g++ make procps \
  coreutils ctags curl gawk gdb git jq lynx netcat ngrep sed sip-tester vim wget \
  bison \
  debhelper \
  default-libmysqlclient-dev \
  dh-systemd \
  docbook-xml \
  docbook2x \
  dpkg-dev \
  erlang-dev \
  flex \
  gcj-jdk \
  libbson-dev \
  libconfuse-dev \
  libcurl4-openssl-dev \
  libdb-dev \
  libev-dev \
  libevent-dev \
  libexpat1-dev \
  libgeoip-dev \
  libhiredis-dev \
  libjansson-dev \
  libjson-c-dev \
  libldap2-dev \
  liblua5.1-0-dev \
  libmaxminddb-dev \
  libmemcached-dev \
  libmnl-dev \
  libmongoc-dev \
  libmono-2.0-dev \
  libncurses5-dev \
  libpcre3-dev \
  libperl-dev \
  libphonenumber-dev \
  libpq-dev \
  librabbitmq-dev \
  libradcli-dev \
  libreadline-dev \
  libsasl2-dev \
  libsctp-dev \
  libsnmp-dev \
  libsqlite3-dev \
  libssl-dev \
  libsystemd-dev \
  libunistring-dev \
  libxml2-dev \
  lua-cjson \
  openssl \
  pkg-config \
  python \
  python-dev \
  python3-dev \
  ruby-dev \
  unixodbc-dev \
  uuid-dev \
  xsltproc \
  zlib1g-dev

ENV MYSQL_ROOT_PASSWORD=ktestsrootpw
RUN DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes mysql-client mysql-server
RUN rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
  && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
  && chmod 777 /var/run/mysqld \
  && find /etc/mysql/ -name '*.cnf' -print0 \
    | xargs -0 grep -lZE '^(bind-address|log)' \
    | xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/' \
  && echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf
RUN mysql_install_db --user=mysql

WORKDIR /usr/local/src
RUN git clone https://github.com/nils-ohlmeier/sipsak
WORKDIR /usr/local/src/sipsak
RUN autoreconf --install
RUN ./configure
RUN make
RUN make install

RUN mkdir -p /usr/local/src/data/GeoLite2
RUN mkdir -p /usr/local/src/tmp
WORKDIR /usr/local/src/tmp
RUN wget -O GeoLite2-City.tar.gz http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
RUN tar xvfz GeoLite2-City.tar.gz
RUN mv GeoLite2-City_*/*.* ../data/GeoLite2/
WORKDIR /usr/local/src
RUN rm -rf tmp

COPY kamailio /usr/local/src/kamailio
WORKDIR /usr/local/src/kamailio
RUN make JAVA_HOME=/usr/lib/jvm/java-gcj RADCLI=1 exclude_modules="db_cassandra db_oracle dnssec ndb_cassandra nsq osp" cfg
RUN make JAVA_HOME=/usr/lib/jvm/java-gcj RADCLI=1 Q=0 CC_EXTRA_OPTS="-Wall" all
RUN make JAVA_HOME=/usr/lib/jvm/java-gcj RADCLI=1 install
WORKDIR src/modules/tls
RUN make install-tls-cert

ENV DBENGINE=MYSQL
ENV DBRWPW=kamailiorw
ENV DBROOTPW=ktestsrootpw

COPY kamailio-tests /usr/local/src/kamailio-tests
COPY kamailio-tests/etc/excludeunits.txt.debian9 /usr/local/src/kamailio-tests/excludeunits.txt
WORKDIR /usr/local/src/kamailio-tests

ENTRYPOINT ["/usr/local/src/kamailio-tests/ktestsctl"]
CMD ["-m", "run"]
