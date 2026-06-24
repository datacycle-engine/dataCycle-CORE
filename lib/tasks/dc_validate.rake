# frozen_string_literal: true

namespace :dc do
  namespace :validate do
    desc 'validate alloy-adapter connector is added'
    task alloy_adapter_connector: :environment do
      gemfile_path = Rails.root.join('Gemfile')
      exit unless gemfile_path.exist?

      print 'check alloy-adapter '
      gemfile_content = File.read(gemfile_path)
      errors = []

      errors << AmazingPrint::Colors.red("datacycle-alloy-adapter missing from Gemfile!\nadd \"gem 'datacycle-alloy-adapter', path: 'vendor/gems/datacycle-alloy-adapter'\" to Gemfile") unless gemfile_content.include?("gem 'datacycle-alloy-adapter'")

      errors << AmazingPrint::Colors.red("datacycle-alloy-adapter submodule missing!\nrun \"git submodule add ../../datacycle/extensions/datacycle-alloy-adapter vendor/gems/datacycle-alloy-adapter\" to add it") unless Rails.root.join('vendor', 'gems', 'datacycle-alloy-adapter').exist?

      unless errors.empty?
        puts(AmazingPrint::Colors.red('✖'))
        abort(errors.join("\n\n"))
      end

      puts AmazingPrint::Colors.green('✔')
    end
  end

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
    puts '----------'

    Rake::Task['dc:validate:alloy_adapter_connector'].invoke
    Rake::Task['dc:validate:alloy_adapter_connector'].reenable
  end
end
