class MigrateTimestampsToLastImportStepTimeInfo < ActiveRecord::Migration[7.1]
  def up
    external_systems = DataCycleCore::ExternalSystem.all
    external_systems.each do |cur_ext_sys|
      cur_ext_sys.import_config.each_key do |key|
        step_json = {
          last_try: cur_ext_sys.last_import,
          last_try_time: cur_ext_sys.last_import_time,
          last_successful_try: cur_ext_sys.last_successful_import,
          last_successful_try_time: cur_ext_sys.last_successful_import_time
        }
        cur_ext_sys.merge_last_import_step_time_info(key, step_json)
      end

      cur_ext_sys.download_config.each_key do |key|
        step_json = {
          last_try: cur_ext_sys.last_download,
          last_try_time: cur_ext_sys.last_download_time,
          last_successful_try: cur_ext_sys.last_successful_download,
          last_successful_try_time: cur_ext_sys.last_successful_download_time
        }

        cur_ext_sys.merge_last_import_step_time_info(key, step_json)
      end

      cur_ext_sys.save
    end
  end

  def down
    DataCycleCore::ExternalSystem.update_all(last_import_step_time_info: {})
  end
end
