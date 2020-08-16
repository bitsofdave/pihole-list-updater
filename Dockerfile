FROM ruby:2.7.1

RUN apt-get update -y

RUN apt-get install -y cron sqlite3

# Docker for Raspbian ARM32
RUN curl -fsSL https://get.docker.com -o get-docker.sh
RUN sh get-docker.sh
# ---

WORKDIR /app

ADD Gemfile Gemfile
RUN bundle install

ADD cronjobs/ /etc/cron.d/

RUN crontab /etc/cron.d/updater.cron

CMD cron -f
