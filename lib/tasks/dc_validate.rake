# frozen_string_literal: true

require 'rubocop'
require 'bundler/audit/cli'

namespace :dc do
  namespace :validate do
    namespace :code do
      desc 'run bundle audit, brakeman, rubocop and fasterer'
      task :all do
        sh 'bundle exec bundle audit check --update --ignore CVE-2021-21288 CVE-2021-21305'
        sh "bundle exec brakeman -c #{DataCycleCore::Engine.root.join('config', 'brakeman.yml')}"
        sh 'bundle exec rubocop --format fuubar'
        sh 'bundle exec fasterer'
      end
    end
  end
end
