# frozen_string_literal: true

namespace :dc do
  namespace :templates do
    desc 'validate template definitions'
    task :validate, [:debug] => :environment do |_, args|
      puts "validating new template definitions\n"
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new
      template_importer.validate

      template_importer.render_mixin_errors
      template_importer.render_errors
      template_importer.render_mixin_paths if args.debug.to_s.casecmp('true').zero?

      template_importer.valid? ? puts('[done] ... looks good') : exit(-1)
    end

    desc 'import and update all template definitions'
    task :import, [:debug] => :environment do |_, args|
      before_import = Time.zone.now
      puts "importing new template definitions\n"
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new
      template_importer.import

      template_importer.render_duplicates
      template_importer.render_mixin_errors
      template_importer.render_errors
      template_importer.render_mixin_paths if args.debug.to_s.casecmp('true').zero?

      template_importer.valid? ? puts("[done] ... looks good (Duration: #{(Time.zone.now - before_import).round} sec)") : exit(-1)

      template_statistics = DataCycleCore::MasterData::Templates::TemplateStatistics.new(start_time: before_import)
      template_statistics.update_statistics
      template_statistics.render_statistics

      puts "\n"
    end
    namespace :migrations do
      task :validate, [:debug] => :environment do |_, _args|
        puts "validating new data definitions\n"
      end
      task :data_definitions, [:debug] => :environment do |_, _args|
        puts "migrate to new data_definitions\n"
      end
      task :universal_classifications, [:debug] => :environment do |_, _args|
        puts "migrate classifications to universal classifications\n"
        if DataCycleCore.data_definition_mapping.dig('universal_classifications').blank?
          puts 'no mappings found'
          exit(-1)
        end
        classifications = DataCycleCore.data_definition_mapping.dig('universal_classifications')
        ap classifications
        ActiveRecord::Base.connection.execute <<-SQL.squish
          UPDATE classification_contents SET relation = 'universal_classifications' WHERE relation IN ('#{classifications.join("','")}');
          UPDATE classification_content_histories SET relation = 'universal_classifications' WHERE relation IN ('#{classifications.join("','")}');
        SQL
      end
    end
  end
end
