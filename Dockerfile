# syntax=docker/dockerfile:1.2

FROM ruby:2.7.1-slim

MAINTAINER DataCycle patrick_rainer

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8
ENV TZ=Europe/Vienna

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y build-essential software-properties-common locales wget links curl gnupg2 rsync bc git git-core apt-transport-https libxml2 libxml2-dev libcurl4-openssl-dev gawk libreadline6-dev libyaml-dev autoconf libgdbm-dev libncurses5-dev automake libtool bison libffi-dev zlib1g-dev openssl tzdata libpq-dev xvfb libgtk2.0-0 libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libgeos-dev libproj-dev nano ghostscript ffmpeg libtag1-dev libavformat-dev libmpg123-dev libsamplerate-dev libsndfile-dev cimg-dev libavcodec-dev libswscale-dev openssh-client ca-certificates && \
                        update-ca-certificates

# git config
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan git.pixelpoint.biz >> ~/.ssh/known_hosts

# PostgreSQL
RUN add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main"
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get update
RUN apt-get install -y postgresql-11 postgresql-client-11

# npm
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs build-essential

# yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn

RUN gem install bundler -v 2.0

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# update imageMagick
RUN cd /tmp \
    && wget https://imagemagick.org/download/ImageMagick.tar.gz \
    && mkdir ImageMagick \
    && tar xf ImageMagick.tar.gz -C ImageMagick --strip-components 1 \
    && cd ImageMagick \
    && ./configure \
    && make \
    && make install \
    && ldconfig /usr/local/lib

RUN rm -Rf /tmp/ImageMagick

# install phash
RUN git clone https://docker-image-read-token:mH17pwgeBm_EWGzq1WRq@git.pixelpoint.biz/data-cycle/phash.git /tmp/phash
RUN cd /tmp/phash \
    && ./configure --disable-video-hash --disable-audio-hash --disable-pthread \
    && make \
    && make install

#clean up
RUN rm -Rf /tmp/phash

RUN apt-get autoremove


# FROM git.pixelpoint.biz:5050/data-cycle/data-cycle-core/base:latest

RUN mkdir -p /var/www/app
RUN mkdir -p /var/www/app/vendor/gems

ENV GEM_HOME /gems
ENV BUNDLE_PATH $GEM_HOME
ENV BUNDLE_APP_CONFIG $BUNDLE_PATH
ENV BUNDLE_BIN $BUNDLE_PATH/bin

ENV PATH /app/bin:$BUNDLE_BIN:$PATH

ADD Gemfile /var/www/app/Gemfile
ADD Gemfile.lock /var/www/app/Gemfile.lock

ADD vendor/gems/data-cycle-core /var/www/app/vendor/gems/data-cycle-core

ADD . /var/www/app
RUN chown -R nobody:nogroup /var/www/app
USER nobody

WORKDIR /var/www/app
