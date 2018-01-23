FROM patrickrainer/data_cycle_base

RUN mkdir -p /var/www/app

ENV BUNDLE_PATH /gems
ENV BUNDLE_HOME /gems
ENV GEM_HOME /gems
ENV GEM_PATH /gems
ENV PATH /gems/bin:$PATH
ENV DUMMY_PATH /var/www/app/test/dummy

ADD Gemfile /var/www/app/Gemfile
ADD Gemfile.lock /var/www/app/Gemfile.lock
ADD data_cycle_core.gemspec /var/www/app/data_cycle_core.gemspec

ADD . /var/www/app
RUN chown -R nobody:nogroup /var/www/app
USER nobody

WORKDIR /var/www/app
