# frozen_string_literal: true

namespace :dc do
  namespace :templates do
    desc 'validate template definitions'
    task validate: :environment do
      puts "validating new template definitions\n"
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new
      template_importer.validate

      if template_importer.mixin_errors.present?
        puts 'the following mixins have multiple definitions:'
        ap template_importer.mixin_errors
      end

      if template_importer.errors.present?
        puts 'the following errors were encountered during validation:'
        ap template_importer.errors
      end

      template_importer.valid? ? puts('[done] ... looks good') : exit(-1)
    end

    desc 'import and update all template definitions'
    task import: :environment do
      before_import = Time.zone.now
      puts "importing new template definitions\n"
      template_importer = DataCycleCore::MasterData::Templates::TemplateImporter.new
      template_importer.import

      if template_importer.duplicates.present?
        puts 'INFO: the following templates are overwritten:'
        ap template_importer.duplicates
      end

      if template_importer.mixin_errors.present?
        puts 'the following mixins have multiple definitions:'
        ap template_importer.mixin_errors
      end

      if template_importer.errors.present?
        puts 'the following errors were encountered during import:'
        ap template_importer.errors
      end

      template_importer.valid? ? puts("[done] ... looks good (Duration: #{(Time.zone.now - before_import).round} sec)") : exit(-1)

      puts "\nchecking for usage of not translatable embedded"
      embedded_validator = DataCycleCore::MasterData::Templates::NotTranslatableEmbeddedValidator.new
      embedded_validator.validate

      if embedded_validator.valid?
        puts('[done] ... looks good')
      else
        puts "\nERROR: the following templates use not translatable embedded:"
        ap embedded_validator.errors
        puts "\nHINT: add ':translated: true' to the respective embedded propert(y)/(ies) to make it work"
        exit(-1)
      end

      template_statistics = DataCycleCore::MasterData::Templates::TemplateStatistics.new(start_time: before_import)
      template_statistics.update_statistics

      if template_statistics.outdated_templates.present?
        puts "\nWARNING: the following templates were not updated:"
        puts "#{'template_name'.ljust(40)} | #{'cache_valid_since'.ljust(38)} | #{'#things'.ljust(12)} | #{'#things_hist'.ljust(12)}"
        puts '-' * 112
        template_statistics.outdated_templates.each do |value|
          puts "#{value[:name].to_s.ljust(40)} | #{value[:cache_valid_since].to_s(:long_usec).ljust(38)} | #{value[:count].to_s.rjust(12)} | #{value[:count_history].to_s.rjust(12)}"
        end
      end

      puts "\n"
    end
  end
end
