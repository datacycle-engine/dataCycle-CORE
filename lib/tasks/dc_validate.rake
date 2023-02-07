# frozen_string_literal: true

namespace :dc do
  desc 'run all validations for code and templates, add | seperated list of additional CVEs to ignore'
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
end
