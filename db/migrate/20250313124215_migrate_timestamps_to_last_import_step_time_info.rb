class MigrateTimestampsToLastImportStepTimeInfo < ActiveRecord::Migration[7.1]
  def up
    external_systems = DataCycleCore::ExternalSystem.all
    external_systems.each do |external_system|
      migrate_config_steps(external_system, :import)
      migrate_config_steps(external_system, :download)
      external_system.save
    end
  end

  def down
    DataCycleCore::ExternalSystem.update_all(last_import_step_time_info: {})
  end

  def migrate_config_steps(external_system, action)
    case action
    when :import
      config = external_system.import_config
      key_prefix = 'i_'
      last_try = external_system.last_import
      last_try_time = external_system.last_import_time
      last_successful_try = external_system.last_successful_import
      last_successful_try_time = external_system.last_successful_import_time
    when :download
      config = external_system.download_config
      key_prefix = 'd_'
      last_try = external_system.last_download
      last_try_time = external_system.last_download_time
      last_successful_try = external_system.last_successful_download
      last_successful_try_time = external_system.last_successful_download_time
    end

    return if config.blank?
    config.each_key do |key|
      step_json = {
        last_try: last_try,
        last_try_time: last_try_time,
        last_successful_try: last_successful_try,
        last_successful_try_time: last_successful_try_time
      }
      external_system.merge_last_import_step_time_info(key_prefix + key, step_json)
    end
  end
end
