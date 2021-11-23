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

RUN bundle install --jobs $(nproc) --without development test

RUN mkdir -p /app/node_modules \
    && chown ruby:ruby -R /app/node_modules

RUN yarn

RUN bundle exec vite build

# make sure docker-compose bind mount dirs exists inside the container
RUN mkdir -p /app/log \
    && chown ruby:ruby -R /app/log \
    && chmod -R 0664 /app/log
RUN mkdir -p /app/public/uploads \
    && chown ruby:ruby -R /app/public/uploads

# create folder for local importer
RUN mkdir -p /app/private/import \
    && chown ruby:ruby -R /app/private/import

# create a temporary folder to update /app/public/assets in named volumes
RUN mkdir -p /app/dc_volumes/public/assets \
    && cp -Rf /app/public/assets/* /app/dc_volumes/public/assets/. \
    && chown ruby:ruby -R /app/dc_volumes/public/assets

# create a temporary folder to update docker configs in named volumes
RUN mkdir -p /app/docker \
    && mkdir -p /app/dc_volumes/docker \
    && cp -Rf /app/docker /app/dc_volumes/. \
    && chown ruby:ruby -R /app/dc_volumes/docker

RUN rm -Rf /app/node_modules

COPY vendor/gems/data-cycle-core/docker/docker-entrypoint.sh docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]

CMD ["/app/docker/wait-for-postgres.sh", "bundle", "exec", "puma", "-C", "/app/docker/web/puma.rb"]


###############################################################################

FROM base AS development

ARG APP_DOCKER_ENV="development"
ARG NODE_ENV="development"
ARG RAILS_ENV="development"
ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    APP_DOCKER_ENV="${APP_DOCKER_ENV}"

RUN bundle install --jobs $(nproc)

RUN mkdir -p /app/node_modules \
    && chown ruby:ruby -R /app/node_modules

RUN yarn

ENTRYPOINT ["/app/vendor/gems/data-cycle-core/docker/docker-entrypoint.sh"]

CMD ["/app/vendor/gems/data-cycle-core/docker/wait-for-postgres.sh", "bundle", "exec", "puma", "-C", "/app/vendor/gems/data-cycle-core/docker/web/puma.rb"]
