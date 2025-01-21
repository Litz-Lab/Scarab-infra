# syntax = edrevo/dockerfile-plus

#scarab & dynamorio
INCLUDE+ ./common/Dockerfile.common

##install apache2
#RUN apt-get install --no-install-recommends -y apache2

#reqs https://httpd.apache.org/docs/2.4/install.html
USER root
RUN apt-get install --no-install-recommends -y libpcre2-dev
RUN apt-get install --no-install-recommends -y libexpat1-dev

#get source
WORKDIR $tmpdir
RUN wget https://dlcdn.apache.org/httpd/httpd-2.4.57.tar.gz
RUN tar -xzf httpd-2.4.57.tar.gz

#dependencies
WORKDIR $tmpdir/httpd-2.4.57/srclib
RUN wget https://dlcdn.apache.org//apr/apr-1.7.4.tar.gz
RUN tar -xzf apr-1.7.4.tar.gz
RUN mv apr-1.7.4 apr
RUN wget https://dlcdn.apache.org//apr/apr-util-1.6.3.tar.gz
RUN tar -xzf apr-util-1.6.3.tar.gz
RUN mv apr-util-1.6.3 apr-util

#build and install
WORKDIR $tmpdir/httpd-2.4.57
RUN ./configure
RUN make
RUN make install

#configure server: /usr/local/apache2/conf/httpd.conf
#run server: /usr/local/apache2/bin/apachectl -k start
#testing: /usr/loca/apache2/bin/ab -n 1 -c 1 http://172.17.0.2:80/

CMD ["/bin/bash"]

