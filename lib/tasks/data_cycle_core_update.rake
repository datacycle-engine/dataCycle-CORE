# frozen_string_literal: true

require 'rake_helpers/time_helper'

namespace :data_cycle_core do
  namespace :update do
    desc 'import all external_system configs'
    task import_external_system_configs: [:environment] do
      puts 'importing new external_system configs'
      errors = DataCycleCore::MasterData::ImportExternalSystems.import_all
      if errors.blank?
        puts '[done] ... looks good'
      else
        puts 'the following errors were encountered during import:'
        ap errors
      end
      puts "\n"
    end

    desc 'import classifications'
    task import_classifications: [:environment] do
      before_import = Time.zone.now
      puts 'importing new classification definitions'
      imported_classifications = DataCycleCore::MasterData::ImportClassifications.import_all
      if imported_classifications.size.positive?
        puts('[done] ... looks good')
      else
        exit(-1)
      end

      puts 'checking for unused <Inhaltstypen> classifications'
      data = DataCycleCore::MasterData::ImportClassifications.updated_classification_statistics(before_import)
      if data.present?
        puts "\nWARNING: the following classification_aliases are not updated:"
        puts 'name'.ljust(30) + ' | ' + 'last_seen'.ljust(38) + ' | ' + 'occurrence'
        puts '-' * 82
        data.each do |key, value|
          puts "#{key.to_s.ljust(30)} |  #{value[:seen_at].to_s(:long_usec).ljust(38)} | #{value[:count].to_s.rjust(7)}"
        end
      else
        puts('[done] ... looks good')
      end
      puts "\n"
    end

    desc 'import all template definitions'
    task import_templates: [:environment] do
      before_import = Time.zone.now
      puts "importing new template definitions\n"
      errors, duplicates, mixin_duplicates = DataCycleCore::MasterData::ImportTemplates.import_all
      if duplicates.present?
        puts 'INFO: the following templates are overwritten:'
        ap duplicates
      end
      if mixin_duplicates.present?
        puts 'INFO: the following mixins are overwritten:'
        ap mixin_duplicates
      end
      if errors.present?
        puts 'the following errors were encountered during import:'
        ap errors
      end
      errors.blank? ? puts('[done] ... looks good') : exit(-1)
      puts "\nchecking for usage of not translatable embedded"
      templates = DataCycleCore::MasterData::ImportTemplates.find_not_translatable_embedded
      if templates.present?
        puts "\nERROR: the following templates use not translatable embedded:"
        ap templates
        puts "\nHINT: add ':translated: true' to the respective embedded propert(y)/(ies) to make it work"
        exit(-1)
      else
        puts('[done] ... looks good')
      end

      outdated_templates = DataCycleCore::MasterData::ImportTemplates.updated_template_statistics(before_import)
      if outdated_templates.present?
        puts "\nWARNING: the following templates are not updated:"
        puts "#{'template_name'.ljust(20)} | #{'template_updated_at'.ljust(38)} | #{'#things'.ljust(12)} | #{'#things_hist'.ljust(12)}"
        puts '-' * 92
        outdated_templates.each do |key, value|
          puts "#{key.to_s.ljust(20)} | #{value[:template_updated_at].to_s(:long_usec).ljust(38)} | #{value[:count].to_s.rjust(12)} | #{value[:count_history].to_s.rjust(12)}"
        end
      end
      puts "\n"
    end

    desc 'delete history of a specific template_name'
    task :delete_history, [:template_name] => [:environment] do |_, args|
      template = DataCycleCore::Thing.find_by(template_name: args[:template_name], template: true)
      if template.nil?
        puts 'ERROR: template not found. The following templates are known to the system:'
        puts DataCycleCore::Thing.where(template: true).pluck(:template_name).sort
        exit(-1)
      end

      data_object = DataCycleCore::Thing::History.where(template_name: args[:template_name], template: false)
      total_items = data_object.count
      puts "DELETE history for: #{args[:template_name]} (#{total_items}) - (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
      index = 0

      data_object.find_each do |data_item|
        # progress_bar
        if total_items > 49
          if (index % 500).zero?
            fraction = (index / (total_items / 100.0)).round(0)
            fraction = 100 if fraction > 100
            print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
          end
        else
          fraction = (((index * 1.0) / total_items) * 100.0).round(0)
          fraction = 100 if fraction > 100
          print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
        end
        index += 1

        data_item.destroy_content
      end
      puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
    end

    desc 'replace the data-definitions of all data-types in the Database with the templates in the Database'
    task :update_all_templates_sql, [:history] => [:environment] do |_, args|
      temp = Time.zone.now
      puts "#{'template_name'.ljust(41)} | #updated | of total | process time/s \r"
      puts '-' * 80 + " \r"
      DataCycleCore::Thing.where(template: true).each do |template_object|
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_template_sql"].invoke(template_object.template_name, args.fetch(:history, false))
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_template_sql"].reenable
      end
      puts '-' * 80 + " \r"
      puts "total time: #{TimeHelper.format_time(Time.zone.now - temp, 6, 6, 's')} \r"
    end

    desc 'replace a given data-definition with its recent template'
    task :update_template_sql, [:template_name, :history] => [:environment] do |_, args|
      template = DataCycleCore::Thing.find_by(template_name: args[:template_name], template: true)
      total_items = DataCycleCore::Thing.where(template_name: args[:template_name], template: false).count

      if template.nil?
        puts "ERROR: template [#{args[:template_name]}] not found. The following templates are known to the system:"
        puts DataCycleCore::Thing.where(template: true).map(&:template_name)
        exit(-1)
      end

      temp = Time.zone.now

      update_sql = <<-EOS
        UPDATE things
        SET
          schema = '#{template.schema.to_json}',
          boost = #{template.schema.dig('boost') || 'NULL'},
          content_type = '#{template.schema.dig('content_type')}',
          template_updated_at = '#{Time.zone.now}'
        WHERE template_name='#{args[:template_name]}' and template=false
      EOS

      affected_items = ActiveRecord::Base.connection.update(ActiveRecord::Base.send(:sanitize_sql_for_conditions, update_sql))

      puts "#{args[:template_name].ljust(41)} | #{(affected_items || 0).to_s.rjust(8)} | #{(total_items || 0).to_s.rjust(8)} | #{TimeHelper.format_time(Time.zone.now - temp, 5, 6, 's')} \r"

      next unless args.fetch(:history, false).to_s == 'true'

      # history update
      total_history_items = DataCycleCore::Thing::History.where(template_name: args[:template_name], template: false).count
      temp = Time.zone.now

      update_history_sql = <<-EOS
        UPDATE thing_histories
        SET schema = '#{template.schema.to_json}',
        boost = #{template.schema.dig('boost') || 'NULL'},
        content_type = '#{template.schema.dig('content_type')}'
        WHERE template_name='#{args[:template_name]}' and template=false
      EOS

      affected_history_items = ActiveRecord::Base.connection.update(ActiveRecord::Base.send(:sanitize_sql_for_conditions, update_history_sql))

      puts "#{'thing_histories'.ljust(15)} | #{args[:template_name].ljust(25)} | #{(affected_history_items || 0).to_s.rjust(7)} | #{(total_history_items || 0).to_s.rjust(7)} | #{TimeHelper.format_time(Time.zone.now - temp, 5, 6, 's')} \r"
    end

    desc 'auto_tag all images (without Cloud Vision Tags)'
    task auto_tagging: [:environment] do
      abort('Feature AutoTagging has to be enabled!') unless DataCycleCore::Feature::AutoTagging.enabled?
      taggable_templates = ['Bild']
      tag_property = :cloud_vision_tags

      query = DataCycleCore::Thing.where(template: false, template_name: taggable_templates)
      max_items = query.count

      puts "AutoTagging all untagged Things with template #{taggable_templates} (#{max_items}) - (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
      DataCycleCore::ProgressBarService.for_shell(max_items) do |pb|
        query.find_each do |image|
          pb.inc
          next if image.send(tag_property).present?
          image.auto_tag
        end
      end
    end
  end
end
