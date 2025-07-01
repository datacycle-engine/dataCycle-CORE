# frozen_string_literal: true

namespace :dc do
  desc 'run all validations for code and templates, add | seperated list of additional CVEs to ignore'
  task :validate, [:verbose] => :environment do |_, args|
    Rake::Task['dc:code:validate:bundle_audit'].invoke
    Rake::Task['dc:code:validate:bundle_audit'].reenable
    puts '----------'

    Rake::Task['dc:code:validate:brakeman'].invoke
    Rake::Task['dc:code:validate:brakeman'].reenable
    puts '----------'

    Rake::Task['dc:code:validate:rubocop'].invoke
    Rake::Task['dc:code:validate:rubocop'].reenable
    puts '----------'

    Rake::Task['dc:code:validate:fasterer'].invoke
    Rake::Task['dc:code:validate:fasterer'].reenable
    puts '----------'

    Rake::Task['dc:external_systems:validate'].invoke
    Rake::Task['dc:external_systems:validate'].reenable
    puts '----------'

    Rake::Task['dc:templates:validate'].invoke(args.verbose)
    Rake::Task['dc:templates:validate'].reenable
    puts '----------'

    Rake::Task['dc:features:validate'].invoke(args.verbose)
    Rake::Task['dc:features:validate'].reenable
    puts '----------'

    Rake::Task['zeitwerk:check'].invoke
    Rake::Task['zeitwerk:check'].reenable
  end
end
