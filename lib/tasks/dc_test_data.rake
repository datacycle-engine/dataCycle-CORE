# frozen_string_literal: true

namespace :dc do
  namespace :test_data do
    desc 'Generate one complete dummy record per creatable template, created by the system (opt-in; safe in production). ' \
         'ENV: LOCALES=de,en (default: all available), COLLECTION, COLLECTION_ID=<existing collection, wins over COLLECTION>, ' \
         'MAX_DEPTH, LIFE_CYCLE=Archiv (stage name; empty to skip), TEMPLATES=a,b, ' \
         'INCLUDE_NON_CREATABLE=true (also templates whose schema declares :creatable: off), ' \
         'DRY_RUN=true (generate, print the full report including the resolved collection, then roll it all back)'
    task generate: :environment do
      options = {
        locales: ENV['LOCALES'].presence&.split(',')&.map(&:strip),
        collection_name: ENV.fetch('COLLECTION', DataCycleCore::TestData::Generator::DEFAULT_COLLECTION),
        collection_id: ENV.fetch('COLLECTION_ID', nil),
        max_depth: ENV.fetch('MAX_DEPTH', 4).to_i,
        life_cycle: ENV.fetch('LIFE_CYCLE', 'Archiv').presence,
        template_names: ENV['TEMPLATES'].presence&.split(',')&.map(&:strip),
        include_non_creatable: ENV['INCLUDE_NON_CREATABLE'] == 'true'
      }

      # Named before the run and not only in the report after it. COLLECTION_ID reaches any
      # collection in the installation, and a typo that happens to hit an existing one is
      # indistinguishable from a correct id in the report's counts — so it is worth seeing while
      # there is still time to interrupt, which the transaction below then rolls back. Resolved
      # twice on this path (once here, once in the generator); one indexed lookup either way.
      puts "Collection: #{DataCycleCore::TestData::Report.describe_collection(DataCycleCore::WatchList.find(options[:collection_id]))}" if options[:collection_id].present?

      report = nil

      # All-or-nothing on both branches, DRY_RUN because rolling back is its whole point and a real
      # run because a SIGINT would otherwise leave whatever was already written sitting in the
      # collection and never reach `puts report`, so nothing would say what landed where. Not for the
      # configured timeouts: statement_timeout is per statement and idle_in_transaction_session_timeout
      # only fires on a session sitting idle inside a transaction, and a busy run of short inserts
      # trips neither, however long INCLUDE_NON_CREATABLE=true without TEMPLATES takes.
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
