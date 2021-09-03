# syntax=docker/dockerfile:1.2

FROM git.pixelpoint.biz:5050/data-cycle/data-cycle-core/base:dockerize-1.0 as base

#RUN echo "shopt -s histappend" >> /root/.bashrc
#RUN echo "PROMPT_COMMAND=\"\${PROMPT_COMMAND}\${PROMPT_COMMAND:+;}history -a; history -n\"" >> /root/.bashrc

WORKDIR /app

USER ruby

ARG APP_DOCKER_ENV="production"
ARG NODE_ENV="production"
ARG RAILS_ENV="production"
ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    APP_DOCKER_ENV="${APP_DOCKER_ENV}" \
    PATH="${PATH}:/home/ruby/.local/bin" \
    USER="ruby"

COPY --chown=ruby:ruby . .

RUN mkdir -p /app/vendor/gems && chown ruby:ruby -R /app/vendor/gems
RUN mkdir -p /app/tmp/sockets && mkdir -p /app/tmp/pids && chown ruby:ruby -R /app/tmp
RUN mkdir -p /app/node_modules && chown ruby:ruby -R /app/node_modules

# make sure volume dirs exists
RUN mkdir -p /app/log && chown ruby:ruby -R /app/log && chmod -R 0664 /app/log

#ENV GEM_HOME /gems
#ENV BUNDLE_PATH $GEM_HOME
#ENV BUNDLE_APP_CONFIG $BUNDLE_PATH
#ENV BUNDLE_BIN $BUNDLE_PATH/bin

#ENV PATH /app/bin:$PATH

# COPY --chown=ruby:ruby Gemfile* ./
RUN bundle install --jobs $(nproc)

CMD ["bash"]

###############################################################################

FROM base AS production

RUN yarn

RUN bundle exec vite build

RUN rm -Rf /app/node_modules

#ADD Gemfile /var/www/app/Gemfile
#ADD Gemfile.lock /var/www/app/Gemfile.lock

#ADD vendor/gems/data-cycle-core /var/www/app/vendor/gems/data-cycle-core

#ADD . /var/www/app
#RUN chown -R nobody:nogroup /var/www/app
#USER nobody

#ENTRYPOINT ["/app/bin/docker-entrypoint-web"]

ENV RAILS_LOG_TO_STDOUT=true
#ENV RUBYOPT "-W:no-deprecated -W:no-experimental"

CMD ["bundle", "exec", "puma", "-C", "/app/vendor/gems/data-cycle-core/docker/web/puma.rb"]
