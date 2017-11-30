FROM debian:stretch

RUN apt-get update
RUN apt-get install --assume-yes apt-utils
RUN apt-get install --assume-yes procps pkg-config gcc g++ make autoconf ctags
RUN apt-get install --assume-yes bison flex libpcre3-dev libxml2-dev libssl-dev
RUN apt-get install --assume-yes git ngrep vim
RUN apt-get install --assume-yes sipsak sip-tester
RUN DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes mysql-client mysql-server default-libmysqlclient-dev

COPY kamailio /usr/local/src/kamailio
WORKDIR /usr/local/src/kamailio
RUN make include_modules="db_mysql tls" cfg
RUN make all
RUN make install
WORKDIR src/modules/tls
RUN make install-tls-cert

COPY kamailio-tests /usr/local/src/kamailio-tests
WORKDIR /usr/local/src/kamailio-tests

CMD /usr/local/src/kamailio-tests/ktestsctl -q run
