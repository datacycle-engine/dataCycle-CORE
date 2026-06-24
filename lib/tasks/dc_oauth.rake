# frozen_string_literal: true

namespace :dc do
  namespace :oauth do
    namespace :clients do
      desc 'create or update the Grafana OAuth client application'
      task upsert_grafana: :environment do
        abort('Missing "GRAFANA_OAUTH_CLIENT_ID"!') if ENV['GRAFANA_OAUTH_CLIENT_ID'].blank?
        abort('Missing "GRAFANA_OAUTH_CLIENT_SECRET"!') if ENV['GRAFANA_OAUTH_CLIENT_SECRET'].blank?

        grafana_app = Doorkeeper::Application.find_by(name: 'Grafana')
        if grafana_app
          grafana_app.update!(
            redirect_uri: "#{ENV.fetch('APP_PROTOCOL', 'http')}://#{ENV.fetch('APP_HOST', 'localhost:3003')}/grafana/login/generic_oauth",
            scopes: 'openid profile email roles',
            uid: ENV['GRAFANA_OAUTH_CLIENT_ID'],
            secret: ENV['GRAFANA_OAUTH_CLIENT_SECRET']
          )
        else
          Doorkeeper::Application.create!(
            name: 'Grafana',
            redirect_uri: "#{ENV.fetch('APP_PROTOCOL', 'http')}://#{ENV.fetch('APP_HOST', 'localhost:3003')}/grafana/login/generic_oauth",
            scopes: 'openid profile email roles',
            uid: ENV['GRAFANA_OAUTH_CLIENT_ID'],
            secret: ENV['GRAFANA_OAUTH_CLIENT_SECRET']
          )
        end
      end
    end
  end
end
