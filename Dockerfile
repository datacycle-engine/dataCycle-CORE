FROM git.pixelpoint.biz:5050/data-cycle/data-cycle-core/base:latest

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

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - && apt -y install nodejs

ADD . /var/www/app
RUN chown -R nobody:nogroup /var/www/app
USER nobody

WORKDIR /var/www/app
