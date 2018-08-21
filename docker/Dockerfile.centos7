FROM centos:7

RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN yum update -y && yum install -y --setopt=tsflags=nodocs epel-release && \
    yum install -y --setopt=tsflags=nodocs which gcc make bison curl-devel \
    expat-devel flex hiredis-devel \
    jansson-devel json-c-devel libevent-devel libxml2-devel \
    lksctp-tools-devel lm_sensors-devel mysql-devel net-snmp-devel \
    openldap-devel openssl-devel pcre-devel perl-ExtUtils-Embed perl-devel \
    postgresql-devel libconfuse-devel python-devel sqlite-devel unixODBC-devel \
    zlib-devel lua-devel rpm-build erlang erlang-erl_interface db4-devel \
    hiredis-devel GeoIP-devel libmemcached-devel mod_perl-devel glib2-devel \
    libpurple-devel libunistring-devel xmlrpc-c-devel iputils git \
    libuuid-devel systemd-devel squirrel-devel uuid-devel librabbitmq-devel \
    gcc-c++ autoconf automake wget mono-devel mongodb-devel mongo-c-driver \
    mongo-c-driver-devel radiusclient-ng-devel libmaxminddb-devel libev-devel \
    openssl

ENV MYSQL_ROOT_PASSWORD=ktestsrootpw

# From https://github.com/CentOS/CentOS-Dockerfiles/blob/master/mariadb/centos7/Dockerfile
RUN yum -y install --setopt=tsflags=nodocs epel-release && \ 
    yum -y install --setopt=tsflags=nodocs mariadb-server bind-utils pwgen psmisc hostname && \ 
    yum -y erase vim-minimal && \
    yum -y update && yum clean all

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
RUN make JAVA_HOME=/usr/lib/jvm/java-gcj RADCLI=1 exclude_modules="db_cassandra db_oracle dnssec ndb_cassandra nsq osp app_java acc_radius auth_radius peering misc_radius phonenum" cfg
RUN make JAVA_HOME=/usr/lib/jvm/java-gcj RADCLI=1 Q=0 CC_EXTRA_OPTS="-Wall" all
RUN make JAVA_HOME=/usr/lib/jvm/java-gcj RADCLI=1 install
WORKDIR src/modules/tls
RUN make install-tls-cert

ENV DBENGINE=MYSQL
ENV DBRWPW=kamailiorw
ENV DBROOTPW=ktestsrootpw

# Moved down here for convenience
RUN mysql_install_db --user=mysql

COPY kamailio-tests /usr/local/src/kamailio-tests
COPY kamailio-tests/etc/excludeunits.txt.centos7 /usr/local/src/kamailio-tests/excludeunits.txt
WORKDIR /usr/local/src/kamailio-tests

ENTRYPOINT ["/usr/local/src/kamailio-tests/ktestsctl"]
CMD ["-m", "run"]
