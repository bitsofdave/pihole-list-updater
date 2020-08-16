FROM ruby:2.7.1

RUN apt-get update -y

RUN apt-get install -y cron sqlite3
# && \
#    apt-get install -y dnsutils

WORKDIR /app

ADD Gemfile Gemfile

RUN bundle install

ADD cronjobs/ /etc/cron.d/

RUN crontab /etc/cron.d/updater.cron

