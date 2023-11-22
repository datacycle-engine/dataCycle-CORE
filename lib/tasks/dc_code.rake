# frozen_string_literal: true

namespace :dc do
  namespace :code do
    namespace :validate do
      desc 'run bundle audit'
      task :bundle_audit, [:ignore_cve] => :environment do |_, args|
        ignore_cve = ['CVE-2021-21288', 'CVE-2021-21305']
        ignore_cve += args.fetch(:ignore_cve, '').split('|')

        sh "bundle exec bundle audit check --update --ignore #{ignore_cve.join(' ')}"
      end

      desc 'run brakeman'
      task brakeman: :environment do
        sh "bundle exec brakeman -c #{DataCycleCore::Engine.root.join('config', 'brakeman.yml')} -q"
      end

      desc 'run rubocop'
      task rubocop: :environment do
        sh 'bundle exec rubocop -P'
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
