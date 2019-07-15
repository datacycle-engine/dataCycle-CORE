FROM patrickrainer/data_cycle_base:2.6.3

RUN mkdir -p /var/www/app
RUN mkdir -p /var/www/app/vendor/gems

ENV BUNDLE_PATH /gems
ENV BUNDLE_HOME /gems
ENV GEM_HOME /gems
ENV GEM_PATH /gems
ENV PATH /gems/bin:$PATH

ADD Gemfile /var/www/app/Gemfile
ADD Gemfile.lock /var/www/app/Gemfile.lock

ADD vendor/gems/data-cycle-core /var/www/app/vendor/gems/data-cycle-core

RUN cd /var/www/app ; gem install bundler
RUN cd /var/www/app ; bundle install
RUN cd /var/www/app/vendor/gems/data-cycle-core ; bundle install

ADD . /var/www/app
RUN chown -R nobody:nogroup /var/www/app
USER nobody

WORKDIR /var/www/app
