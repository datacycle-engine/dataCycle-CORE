# frozen_string_literal: true

namespace :dc do
  namespace :external_systems do
    desc 'validate template definitions'
    task validate: :environment do
      puts "validating new external_system configs\n"
      errors = DataCycleCore::MasterData::ImportExternalSystems.validate_all

      if errors.blank?
        puts(AmazingPrint::Colors.green('[✔] ... looks good 🚀'))
      else
        puts AmazingPrint::Colors.red('🔥 the following errors were encountered during validation:')
        ap errors
        exit(-1)
      end
    end

    desc 'import and update all template definitions'
    task import: :environment do
      tmp = Time.zone.now
      puts 'importing new external_system configs'
      errors = DataCycleCore::MasterData::ImportExternalSystems.import_all

      if errors.blank?
        puts(AmazingPrint::Colors.green("[✔] ... looks good 🚀 (Duration: #{(Time.zone.now - tmp).round} sec)"))
      else
        puts AmazingPrint::Colors.red('🔥 the following errors were encountered during import:')
        ap errors
        exit(-1)
      end
    end

    desc 'set all running imports to failed'
    task fail_running_imports: :environment do
      to_update = DataCycleCore::ExternalSystem.where("external_systems.last_import_step_time_info @? '$.* ? (@.status == \"running\")'")
      puts "setting #{to_update.size} running imports to failed"

      to_update.find_each(&:fail_running_steps!)
    rescue StandardError
      puts AmazingPrint::Colors.red('🔥 there were some errors!')
    end
  end
end
