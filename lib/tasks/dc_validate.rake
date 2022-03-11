# frozen_string_literal: true

namespace :dc do
  namespace :code do
    namespace :validate do
      desc 'run bundle audit, brakeman, rubocop and fasterer'
      task :all do
        sh 'bundle exec bundle audit check --update --ignore CVE-2021-21288 CVE-2021-21305'
        sh "bundle exec brakeman -c #{DataCycleCore::Engine.root.join('config', 'brakeman.yml')} -q"
        sh 'bundle exec rubocop --format fuubar'
        sh 'bundle exec fasterer'
      end
    end
  end
end
