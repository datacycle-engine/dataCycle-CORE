# frozen_string_literal: true

namespace :dc do
  desc 'run all validations for code and templates, add | seperated list of additional CVEs to ignore'
  task :validate, [:verbose] => :environment do |_, args|
    Rake::Task['dc:code:validate:bundle_audit'].invoke
    Rake::Task['dc:code:validate:bundle_audit'].reenable

    Rake::Task['dc:code:validate:brakeman'].invoke
    Rake::Task['dc:code:validate:brakeman'].reenable

    Rake::Task['dc:code:validate:rubocop'].invoke
    Rake::Task['dc:code:validate:rubocop'].reenable

    Rake::Task['dc:code:validate:fasterer'].invoke
    Rake::Task['dc:code:validate:fasterer'].reenable

    Rake::Task['dc:external_systems:validate'].invoke
    Rake::Task['dc:external_systems:validate'].reenable

    Rake::Task['dc:templates:validate'].invoke(args.verbose)
    Rake::Task['dc:templates:validate'].reenable

    Rake::Task['zeitwerk:check'].invoke
    Rake::Task['zeitwerk:check'].reenable
  end
end
