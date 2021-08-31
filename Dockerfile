# syntax=docker/dockerfile:1.2

FROM git.pixelpoint.biz:5050/data-cycle/data-cycle-core/base:dockerize-1.0

#RUN echo "shopt -s histappend" >> /root/.bashrc
#RUN echo "PROMPT_COMMAND=\"\${PROMPT_COMMAND}\${PROMPT_COMMAND:+;}history -a; history -n\"" >> /root/.bashrc

WORKDIR /app

#RUN mkdir -p /var/www/app

USER ruby

ARG NODE_ENV="production"
ARG RAILS_ENV="production"
ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    PATH="${PATH}:/home/ruby/.local/bin" \
    USER="ruby"

COPY --chown=ruby:ruby . .

RUN mkdir -p /app/vendor/gems && chown ruby:ruby -R /app/vendor/gems
RUN mkdir -p /app/tmp && chown ruby:ruby -R /app/tmp
RUN mkdir -p /app/node_modules && chown ruby:ruby -R /app/node_modules

#ENV GEM_HOME /gems
#ENV BUNDLE_PATH $GEM_HOME
#ENV BUNDLE_APP_CONFIG $BUNDLE_PATH
#ENV BUNDLE_BIN $BUNDLE_PATH/bin

#ENV PATH /app/bin:$BUNDLE_BIN:$PATH

# COPY --chown=ruby:ruby Gemfile* ./
RUN bundle install --jobs $(nproc)

#ADD Gemfile /var/www/app/Gemfile
#ADD Gemfile.lock /var/www/app/Gemfile.lock

#ADD vendor/gems/data-cycle-core /var/www/app/vendor/gems/data-cycle-core

#ADD . /var/www/app
#RUN chown -R nobody:nogroup /var/www/app
#USER nobody
#
#WORKDIR /var/www/app
#CMD ["rails", "s"]

ENV RAILS_LOG_TO_STDOUT=true
ENV RUBYOPT "-W:no-deprecated -W:no-experimental"

CMD ["sh", "-c", "bundle exec puma -C /app/vendor/gems/data-cycle-core/docker/web/puma.rb"]
#CMD RAILS_LOG_TO_STDOUT=true RUBYOPT="-W:no-deprecated -W:no-experimental" bundle exec puma -C /app/vendor/gems/data-cycle-core/docker/web/puma.rb