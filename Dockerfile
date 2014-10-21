FROM debian:jessie
MAINTAINER Kevin Larsonneur <klarsonneur@gmail.com>

RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/no-recommends
RUN echo "APT::Get::Assume-Yes "true";" > /etc/apt/apt.conf.d/always-yes
RUN apt-get update && apt-get install --no-install-recommends -y python2.7 python2.7-dev gcc python-setuptools libssl-dev libmysqlclient-dev mysql-client mysql-server

RUN apt-get -q -y install gcc g++ \
         alembic \
         gettext \
         adduser mysql-client \
         libssl-dev libzmq-dev libpq-dev python-psycopg2 python-mako libffi-dev

RUN apt-get -y install git-core
WORKDIR /domogik
RUN git clone git://github.com/domogik/domogik.git /domogik

RUN ./install.py --command-line --user domogik \
  --database_type mysql --database_host localhost --database_name domogik --database_user domogik --database_password domopass

#RUN rm /var/log/domogik/*
ADD domogik-init.sh /domogik-init.sh

CMD ["/domogik-init.sh"]

#VOLUME ["/data"]
EXPOSE 3865 40405 40406 40410 40411 40412
  
  
#RUN adduser --disabled-password --disabled-login domogik
#ADD domogik-0.3.1/ /home/domogik/
#RUN chmod +x /home/domogik/install.sh
#RUN /home/domogik/install.sh --command-line --user domogik \
#  --database_type mysql --database_host localhost --database_name domogik --database_user domogik --database_password domopass



