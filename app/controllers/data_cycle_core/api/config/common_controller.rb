# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      class CommonController < ::DataCycleCore::Api::Config::ApiBaseController
        before_action :authorize_user, :prepare_url_parameters

        def index
          gems = Gem::Specification
            .filter { |gem| gem.full_gem_path.starts_with?('/app/vendor/gems') }
            .map do |gem|
            {
              'type' => 'gem',
              'name' => gem.name,
              'version' => gem.version.to_s,
              'license' => gem.license,
              'description' => gem.summary,
              'homepage' => gem.homepage,
              'base_path' => gem.full_gem_path
            }.compact
          end
          external_systems = DataCycleCore::ExternalSystem.where(deactivated: false).map do |external_system|
            {
              name: external_system.name,
              identifier: external_system.identifier,
              locales: external_system.default_options&.dig('locales'),
              last_download: external_system.last_download,
              last_successful_download: external_system.last_successful_download,
              last_import: external_system.last_import,
              last_successful_import: external_system.last_successful_import,
              last_successful_download_time: external_system.last_successful_download_time,
              last_download_time: external_system.last_download_time
            }
          end
          configs = [{
            templates: DataCycleCore.default_template_paths.map(&:to_s),
            external_systems: external_systems,
            gems: gems,
            activities: {
              count: DataCycleCore::Activity.count,
              widgets: DataCycleCore::Activity.used_widgets
            },
            database: {
              pg_size: DataCycleCore::StatsDatabase.new.load_all_stats.pg_size,
              pg_stats: DataCycleCore::StatsDatabase.new.load_all_stats.load_pg_stats
            },
            mail_options: Rails.application.config.action_mailer.default_options,
            map_options: DataCycleCore.default_map_position['styles']
          }]
          render json: { '@graph' => configs }.to_json
        end

        private

        def authorize_user
          render json: { error: 'Forbidden' }, layout: false, status: :forbidden unless current_user&.is_role?('super_admin')
        end
      end
    end
  end
end
