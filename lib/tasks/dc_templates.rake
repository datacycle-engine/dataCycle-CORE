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
  end
end
