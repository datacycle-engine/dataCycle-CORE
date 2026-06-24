# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      class CommonController < ::DataCycleCore::Api::Config::ApiBaseController
        before_action :prepare_url_parameters

        def index
          authorize! :index, :api_config_common

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
                'basePath' => gem.full_gem_path
              }.compact
            end
          external_systems = DataCycleCore::ExternalSystem.activated.as_json(
            only: [:name, :identifier, :last_download, :last_successful_download, :last_import, :last_successful_import, :last_successful_download_time, :last_download_time, :last_successful_import_time, :last_import_time],
            methods: [:locales],
            camelize_keys: true
          )
          configs = [{
            templates: DataCycleCore.default_template_paths.map(&:to_s),
            externalSystems: external_systems,
            gems: gems,
            activities: {
              count: DataCycleCore::Activity.count,
              widgets: DataCycleCore::Activity.used_widgets
            },
            database: {
              pgSize: DataCycleCore::StatsDatabase.new.load_all_stats.pg_size,
              pgStats: DataCycleCore::StatsDatabase.new.load_all_stats.load_pg_stats&.deep_transform_keys { |key| key.to_s.camelize(:lower) }
            },
            mailOptions: Rails.application.config.action_mailer.default_options,
            mapOptions: DataCycleCore.default_map_position['styles']
          }]
          render json: { '@graph' => configs }.to_json
        end
      end
    end
  end
end
