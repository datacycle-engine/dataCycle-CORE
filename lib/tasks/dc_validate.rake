# frozen_string_literal: true

namespace :dc do
  desc 'run all validations for code and templates, add | seperated list of additional CVEs to ignore'
  task :validate, [:ignore_cve] => :environment do |_, _args|
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:bundle_audit"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:bundle_audit"].reenable

    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:brakeman"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:brakeman"].reenable

    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:rubocop"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:rubocop"].reenable

    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:fasterer"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:code:validate:fasterer"].reenable

    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:external_systems:validate"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:external_systems:validate"].reenable

    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:templates:validate"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:templates:validate"].reenable

    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}zeitwerk:check"].invoke
    Rake::Task["#{ENV['CORE_RAKE_PREFIX']}zeitwerk:check"].reenable
  end
end
