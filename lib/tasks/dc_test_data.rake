# frozen_string_literal: true

namespace :dc do
  namespace :test_data do
    desc 'Generate one complete dummy record per creatable template, created by the system (opt-in; safe in production). ' \
         'ENV: LOCALES=de,en (default: all available), COLLECTION, MAX_DEPTH, LIFE_CYCLE=Archiv (stage name; empty to skip), TEMPLATES=a,b, DRY_RUN=true'
    task generate: :environment do
      options = {
        locales: ENV['LOCALES'].presence&.split(',')&.map(&:strip),
        collection_name: ENV.fetch('COLLECTION', DataCycleCore::TestData::Generator::DEFAULT_COLLECTION),
        max_depth: ENV.fetch('MAX_DEPTH', 4).to_i,
        life_cycle: ENV.fetch('LIFE_CYCLE', 'Archiv').presence,
        template_names: ENV['TEMPLATES'].presence&.split(',')&.map(&:strip)
      }

      report = nil
      ActiveRecord::Base.transaction do
        report = DataCycleCore::TestData::Generator.new(**options).generate

        if ENV['DRY_RUN'] == 'true'
          puts '(DRY_RUN — rolling back all created records)'
          raise ActiveRecord::Rollback
        end
      end

      puts report
    end
  end
end
