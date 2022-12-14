# frozen_string_literal: true

namespace :dc do
  namespace :code do
    desc 'run bundle audit, brakeman, rubocop and fasterer, add | seperated string of additional CVEs'
    task :validate, [:ignore_cve] => :environment do |_, args|
      ignore_cve = ['CVE-2021-21288', 'CVE-2021-21305']
      ignore_cve += args.fetch(:ignore_cve, '').split('|')

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:bundle_audit"].invoke(ignore_cve)
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:brakeman"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:rubocop"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:fasterer"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:templates:validate"].invoke
      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}zeitwerk:check"].invoke
    end

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
        sh 'bundle exec rubocop --format fuubar -P'
      end

      desc 'run fasterer'
      task fasterer: :environment do
        sh 'bundle exec fasterer'
      end
    end
  end

  namespace :templates do
    desc 'validate template definitions'
    task validate: :environment do
      puts "validating new template definitions\n"
      errors = DataCycleCore::MasterData::ImportTemplates.validate_all

      if errors.present?
        puts 'the following errors were encountered during validatiion:'
        ap errors
      end

      errors.blank? ? puts('[done] ... looks good') : exit(-1)
    end
  end
end
