FROM debian:jessie
MAINTAINER Kevin Larsonneur <klarsonneur@gmail.com>

RUN apt-get update && apt-get install --no-install-recommends -y python2.7 python2.7-dev gcc python-setuptools libssl-dev libmysqlclient-dev mysql-client mysql-server

RUN adduser --disabled-password --disabled-login domogik
ADD domogik-0.3.1/ /home/domogik/
RUN chmod +x /home/domogik/install.sh
RUN /home/domogik/install.sh --command-line --user domogik \
  --database_type mysql --database_host localhost --database_name domogik --database_user domogik --database_password domopass



