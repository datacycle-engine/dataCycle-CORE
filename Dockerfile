# syntax=docker/dockerfile:1.2

FROM git.pixelpoint.biz:5050/data-cycle/data-cycle-core/base:dockerize-1.0 as base

WORKDIR /app

USER ruby

# setup history
RUN mkdir -p /home/ruby/hist && chown ruby:ruby -R /home/ruby/hist

RUN echo "shopt -s histappend" >> /home/ruby/.bashrc
RUN echo "PROMPT_COMMAND=\"\${PROMPT_COMMAND}\${PROMPT_COMMAND:+;}history -a; history -n\"" >> /home/ruby/.bashrc

ENV PATH="${PATH}:/home/ruby/.local/bin" \
    USER="ruby"

COPY --chown=ruby:ruby . .

CMD ["bash"]

###############################################################################

FROM base AS production

ARG APP_DOCKER_ENV="production"
ARG NODE_ENV="production"
ARG RAILS_ENV="production"
ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    APP_DOCKER_ENV="${APP_DOCKER_ENV}"

# make sure docker-compose volume dirs exists inside the container
RUN mkdir -p /app/log && chown ruby:ruby -R /app/log && chmod -R 0664 /app/log
RUN mkdir -p /app/public/uploads && chown ruby:ruby -R /app/public/uploads

RUN bundle install --jobs $(nproc) --without development test

RUN mkdir -p /app/node_modules && chown ruby:ruby -R /app/node_modules

RUN yarn

RUN bundle exec vite build

RUN rm -Rf /app/node_modules

ENTRYPOINT ["/app/vendor/gems/data-cycle-core/docker/web/docker-entrypoint.sh"]

CMD ["/app/docker/wait-for-postgres.sh", "bundle", "exec", "puma", "-C", "/app/vendor/gems/data-cycle-core/docker/web/puma.rb"]


###############################################################################

FROM base AS development

ARG APP_DOCKER_ENV="development"
ARG NODE_ENV="development"
ARG RAILS_ENV="development"
ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    APP_DOCKER_ENV="${APP_DOCKER_ENV}"

RUN bundle install --jobs $(nproc)

RUN yarn

RUN bundle exec vite build

RUN rm -Rf /app/node_modules


#ENV GEM_HOME /gems
#ENV BUNDLE_PATH $GEM_HOME
#ENV BUNDLE_APP_CONFIG $BUNDLE_PATH
#ENV BUNDLE_BIN $BUNDLE_PATH/bin

#ENV PATH /app/bin:$PATH

# COPY --chown=ruby:ruby Gemfile* ./

#ADD Gemfile /var/www/app/Gemfile
#ADD Gemfile.lock /var/www/app/Gemfile.lock

#ADD vendor/gems/data-cycle-core /var/www/app/vendor/gems/data-cycle-core

#ADD . /var/www/app
#RUN chown -R nobody:nogroup /var/www/app
#USER nobody

ENTRYPOINT ["/app/vendor/gems/data-cycle-core/docker/web/docker-entrypoint.sh"]

CMD ["bundle", "exec", "puma", "-C", "/app/vendor/gems/data-cycle-core/docker/web/puma.rb"]
