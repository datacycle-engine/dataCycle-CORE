# frozen_string_literal: true

DataCycleCore.load_configurations_for_file('*')

if Rails.env.development?
  config_for_reloader = Rails.configuration.file_watcher.new([], DataCycleCore.configuration_paths.to_h { |v| [v.to_s, 'yml'] }) do
    DataCycleCore.reset_configurations
    DataCycleCore.load_configurations_for_file('*')

    DataCycleCore.features.each_key do |feature|
      "DataCycleCore::Feature::#{feature.classify}".safe_constantize&.reload
    end

    DataCycleCore::Abilities::PermissionsList.reload
  end

  Rails.application.reloader.to_prepare do
    config_for_reloader.execute_if_updated
  end
end
