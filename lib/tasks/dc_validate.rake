# frozen_string_literal: true

namespace :dc do
  namespace :code do
    namespace :validate do
      desc 'run bundle audit, brakeman, rubocop and fasterer, add | seperated string of additional CVEs'
      task :all, [:ignore_cve] => :environment do |_, args|
        ignore_cve = ['CVE-2021-21288', 'CVE-2021-21305']
        ignore_cve += args.fetch(:ignore_cve, '').split('|')

        sh "bundle exec bundle audit check --update --ignore #{ignore_cve.join(' ')}"
        sh "bundle exec brakeman -c #{DataCycleCore::Engine.root.join('config', 'brakeman.yml')} -q"
        sh 'bundle exec rubocop --format fuubar'
        sh 'bundle exec fasterer'
      end
    end
  end
end
