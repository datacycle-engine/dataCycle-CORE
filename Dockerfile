FROM patrickrainer/data_cycle_base

RUN mkdir -p /var/www/app

ENV BUNDLE_PATH /gems
ENV BUNDLE_HOME /gems
ENV GEM_HOME /gems
ENV GEM_PATH /gems
ENV PATH /gems/bin:$PATH

ADD Gemfile /var/www/app/Gemfile
ADD Gemfile.lock /var/www/app/Gemfile.lock
ADD data_cycle_core.gemspec /var/www/app/data_cycle_core.gemspec

#RUN gem install bundler --no-ri --no-rdoc -v 1.16.0

#ADD vendor/gems/data-cycle-core /var/www/app/vendor/gems/data-cycle-core
#ADD vendor/gems/globalize /var/www/app/vendor/gems/globalize

RUN cd /var/www/app ; bundle install
#RUN cd /var/www/app/vendor/gems/data-cycle-core ; bundle install

ADD . /var/www/app
RUN chown -R nobody:nogroup /var/www/app
USER nobody

WORKDIR /var/www/app
