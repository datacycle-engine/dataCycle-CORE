# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :update do
    desc 'import all external_source configs'
    task import_external_source_configs: [:environment] do
      puts 'importing new external_source configs'
      errors = DataCycleCore::MasterData::ImportExternalSources.import_all
      if errors.blank?
        puts '[done] ... looks good'
      else
        puts 'the following errors were encountered during import:'
        ap errors
      end
    end
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
    end

    desc 'import classifications'
    task import_classifications: [:environment] do
      puts 'importing new classification definitions'
      DataCycleCore::MasterData::ImportClassifications.import_all
    end

    desc 'import all template definitions'
    task import_templates: [:environment] do
      puts 'importing new template definitions'
      errors, duplicates = DataCycleCore::MasterData::ImportTemplates.import_all
      if duplicates.present?
        puts 'INFO: the following templates had multiple definitions:'
        ap duplicates
      end
      if errors.present?
        puts 'the following errors were encountered during import:'
        ap errors
      end
      errors.blank? ? puts('[done] ... looks good') : exit(-1)
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
    task :update_all_templates_sql, [:history, :prefix] => [:environment] do |_, args|
      args[:prefix] ||= ''
      temp = Time.zone.now
      puts "#{'table_name'.ljust(15)} | #{'template_name'.ljust(25)} | #updated|of total | process time/s \r"
      puts '-' * 80 + " \r"
      DataCycleCore::Thing.where(template: true).each do |template_object|
        Rake::Task["#{args[:prefix]}data_cycle_core:update:update_template_sql"].invoke(template_object.template_name, args.fetch(:history, false))
        Rake::Task["#{args[:prefix]}data_cycle_core:update:update_template_sql"].reenable
      end
      puts '-' * 80 + " \r"
      puts "total time: #{format_time(Time.zone.now - temp, 6, 6, 's')} \r"
    end

    desc 'replace a given data-definition with its recent template'
    task :update_template_sql, [:template_name, :history] => [:environment] do |_, args|
      template = DataCycleCore::Thing.find_by(template_name: args[:template_name], template: true)
      total_items = DataCycleCore::Thing.where(template_name: args[:template_name], template: false).count

      if template.nil?
        puts 'ERROR: template not found. The following templates are known to the system:'
        puts DataCycleCore::Thing.where(template: true).map(&:template_name)
        exit(-1)
      end

      temp = Time.zone.now

      update_sql = <<-EOS
        UPDATE things
        SET
          schema = '#{template.schema.to_json}',
          updated_at = updated_at + INTERVAL '1 sec'
        WHERE template_name='#{args[:template_name]}' and template=false
      EOS

      affected_items = ActiveRecord::Base.connection.update(ActiveRecord::Base.send(:sanitize_sql_for_conditions, update_sql))

      puts "#{'things'.ljust(15)} | #{args[:template_name].ljust(25)} | #{(affected_items || 0).to_s.rjust(7)} | #{(total_items || 0).to_s.rjust(7)} | #{format_time(Time.zone.now - temp, 5, 6, 's')} \r"

      next unless args.fetch(:history, false).to_s == 'true'

      # history update
      total_history_items = DataCycleCore::Thing::History.where(template_name: args[:template_name], template: false).count
      temp = Time.zone.now

      update_history_sql = <<-EOS
        UPDATE thing_histories
        SET schema = '#{template.schema.to_json}'
        WHERE template_name='#{args[:template_name]}' and template=false
      EOS

      affected_history_items = ActiveRecord::Base.connection.update(ActiveRecord::Base.send(:sanitize_sql_for_conditions, update_history_sql))

      puts "#{'thing_histories'.ljust(15)} | #{args[:template_name].ljust(25)} | #{(affected_history_items || 0).to_s.rjust(7)} | #{(total_history_items || 0).to_s.rjust(7)} | #{format_time(Time.zone.now - temp, 5, 6, 's')} \r"
    end

    desc 'recreate the entries in the search table for all data-types in the Database'
    task rebuild_search: [:environment] do
      puts 'updating search:'
      DataCycleCore::Thing.where(template: true).each do |template_object|
        template_name = template_object.template_name
        data_count = DataCycleCore::Thing.where(template: false).where('template_name = ?', template_name).count
        puts "#{'things'.ljust(25)} | #{template_name.ljust(25)} | #{(data_count || 0).to_s.rjust(10)}"

        strategy = DataCycleCore::Update::UpdateSearch
        DataCycleCore::Update::Update.new(type: DataCycleCore::Thing, template: template_object, strategy: strategy, transformation: nil)
      end
    end

    desc 'update weigths (boost) in search table'
    task update_search: [:environment] do
      puts "#{'content_class'.ljust(30)} | #{'data_definition_name'.ljust(25)} | #{'#entries'.ljust(10)} | new weight"
      puts '-' * 84
      DataCycleCore::Thing.where(template: true).each do |template_object|
        template_name = template_object.template_name
        boost = template_object.schema['boost']

        if boost.present?
          search_entries = DataCycleCore::Search.where(content_data_type: 'DataCycleCore::Thing', data_type: template_name).count

          connection = ActiveRecord::Base.connection
          sql_update = "UPDATE searches SET boost = #{boost} WHERE content_data_type = 'DataCycleCore::Thing' AND data_type = '#{template_name}'"
          connection.exec_query(sql_update)
        end

        puts "#{data_object.to_s.ljust(30)} | #{template_name.ljust(25)} | #{search_entries.to_s.rjust(10)} | #{(boost || 'no search').to_s.rjust(10)}"
      end
    end
  end

  private

  def format_time(time, n, m, unit)
    time.round(m).to_s.split('.').zip([->(x) { x.rjust(n) }, ->(x) { x.ljust(m, '0') }]).map { |x, f| f.call(x) }.join('.') + " #{unit}"
  end
end
