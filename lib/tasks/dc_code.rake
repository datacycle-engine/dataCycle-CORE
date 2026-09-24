# frozen_string_literal: true

namespace :dc do
  namespace :code do
    namespace :validate do
      desc 'run bundle audit'
      task :bundle_audit, [:config_file_path] => :environment do |_, args|
        config_file_path = args.config_file_path.presence || DataCycleCore::Engine.root.join('.bundler-audit.yml')

        sh "bundle exec bundle audit check --update --config #{config_file_path}"
      end

      desc 'run brakeman'
      task brakeman: :environment do
        sh "bundle exec brakeman -c #{DataCycleCore::Engine.root.join('config', 'brakeman.yml')}"
      end

      desc 'run rubocop'
      task rubocop: :environment do
        sh 'bundle exec rubocop'
      end

      desc 'audit JS packages'
      task js_audit: :environment do
        # pnpm exits non-zero only for advisories at/above --audit-level that are not
        # listed in auditConfig.ignoreGhsas, so this fails on high/critical only.
        #
        # --ignore-registry-errors keeps an unreachable audit endpoint from failing the run:
        # npm's POST /-/npm/v1/security/audits/quick answered 500 and then timed out for
        # hours on 2026-09-04, aborting dc:validate before brakeman and rubocop ran.
        sh 'pnpm audit --audit-level high --ignore-registry-errors'
      end
    end
  end
end
