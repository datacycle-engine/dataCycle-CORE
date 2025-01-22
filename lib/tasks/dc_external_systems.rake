# frozen_string_literal: true

namespace :dc do
  namespace :external_systems do
    desc 'validate template definitions'
    task validate: :environment do
      puts "[EXTERNAL_SYSTEMS] validating new external_system configs\n"
      errors = DataCycleCore::MasterData::ImportExternalSystems.validate_all

      if errors.blank?
        puts('[EXTERNAL_SYSTEMS] looks good')
      else
        puts '[EXTERNAL_SYSTEMS] the following errors were encountered during validation:'
        ap errors
        exit(-1)
      end
    end

    desc 'import and update all template definitions'
    task import: :environment do
      tmp = Time.zone.now
      puts '[EXTERNAL_SYSTEMS] importing new external_system configs'
      errors = DataCycleCore::MasterData::ImportExternalSystems.import_all

      if errors.blank?
        puts("[EXTERNAL_SYSTEMS] looks good (Duration: #{(Time.zone.now - tmp).round} sec)")
      else
        puts '[EXTERNAL_SYSTEMS] the following errors were encountered during import:'
        ap errors
        exit(-1)
      end
    end
  end
end
