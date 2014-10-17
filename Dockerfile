FROM debian:jessie
MAINTAINER Kevin Larsonneur <klarsonneur@gmail.com>

RUN apt-get update && apt-get install --no-install-recommends -y python2.7 python2.7-dev gcc python-setuptools libssl-dev libmysqlclient-dev mysql-client mysql-server

RUN adduser domogik -p domopass
ADD domogik-0.3.1/ /home/domogik/
RUN /home/domogik/install.sh



