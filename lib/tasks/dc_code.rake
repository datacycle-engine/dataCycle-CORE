# frozen_string_literal: true

namespace :dc do
  namespace :code do
    namespace :validate do
      desc 'run bundle audit'
      task :bundle_audit, [:config_file_path] => :environment do |_, args|
        if args.config_file_path.present?
          config_file_path = args.config_file_path
        else
          config_file_path = DataCycleCore::Engine.root.join('.bundler-audit.yml')
        end

        sh "bundle exec bundle audit check --update --config #{config_file_path}"
      end

      desc 'run brakeman'
      task brakeman: :environment do
        sh "bundle exec brakeman -c #{DataCycleCore::Engine.root.join('config', 'brakeman.yml')} -q --except EOLRails"
      end

      desc 'run rubocop'
      task rubocop: :environment do
        sh 'bundle exec rubocop'
      end

      desc 'run fasterer'
      task fasterer: :environment do
        sh 'bundle exec fasterer'
      end

      desc 'audit JS packages'
      task js_audit: :environment do
        puts 'pnpm audit --audit-level high'
        system('pnpm audit --audit-level high')

        exit($CHILD_STATUS.exitstatus) if $CHILD_STATUS.exitstatus >= 16
      end
    end
  end
end
