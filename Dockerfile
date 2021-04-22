# syntax=docker/dockerfile:1.0.0-experimental

FROM ruby:2.7.1-alpine3.12

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND noninteractive

RUN apk add --no-cache ruby ruby-dev build-essential software-properties-common locales wget links curl gnupg2 rsync bc git git-core apt-transport-https libxml2 libxml2-dev libcurl4-openssl-dev openssl tzdata gawk libreadline6-dev libyaml-dev autoconf libgdbm-dev libncurses5-dev automake libtool bison libffi-dev zlib1g-dev openssl tzdata libpq-dev nodejs ca-certificates xvfb libgtk2.0-0 libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libgeos-dev libproj-dev nano ghostscript ffmpeg libtag1-dev libavformat-dev libmpg123-dev libsamplerate-dev libsndfile-dev cimg-dev libavcodec-dev libswscale-dev openssh-client

# git config
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan git.pixelpoint.biz >> ~/.ssh/known_hosts

RUN apk add postgresql-11 postgresql-client-11 --no-cache --repository="deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main"
RUN apk add yarn --no-cache --repository="deb https://dl.yarnpkg.com/debian/ stable main"

RUN gem install bundler -v 2.0

# FROM git.pixelpoint.biz:5050/data-cycle/data-cycle-core/base:latest

# RUN mkdir -p /var/www/app
# RUN mkdir -p /var/www/app/vendor/gems

# ENV GEM_HOME /gems
# ENV BUNDLE_PATH $GEM_HOME
# ENV BUNDLE_APP_CONFIG $BUNDLE_PATH
# ENV BUNDLE_BIN $BUNDLE_PATH/bin

# ENV PATH /app/bin:$BUNDLE_BIN:$PATH

# ADD Gemfile /var/www/app/Gemfile
# ADD Gemfile.lock /var/www/app/Gemfile.lock

# ADD vendor/gems/data-cycle-core /var/www/app/vendor/gems/data-cycle-core

# RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - && apt -y install nodejs

# ADD . /var/www/app
# RUN chown -R nobody:nogroup /var/www/app
# USER nobody

# WORKDIR /var/www/app
