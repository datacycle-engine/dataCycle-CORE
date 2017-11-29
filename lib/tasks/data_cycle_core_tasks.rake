FIXNUM_MAX = (2**(0.size * 8 - 2) - 1)

delete_classifications = <<-eos
  DELETE FROM classifications;
  DELETE FROM classification_groups;
  DELETE FROM classification_aliases;
  DELETE FROM classification_trees;
  DELETE FROM classification_tree_labels;
eos

delete_secondary_data = <<-eos
  DELETE FROM watch_list_data_hashes;
  DELETE FROM watch_lists;
  DELETE FROM subscriptions;
  DELETE FROM data_links;
eos

delete_contents = <<-eos
  DELETE FROM creative_works;
  DELETE FROM creative_work_translations;
  DELETE FROM events;
  DELETE FROM event_translations;
  DELETE FROM persons;
  DELETE FROM person_translations;
  DELETE FROM places;
  DELETE FROM place_translations;

  DELETE FROM creative_work_events;
  DELETE FROM creative_work_persons;
  DELETE FROM creative_work_places;
  DELETE FROM event_persons;
  DELETE FROM event_places;
  DELETE FROM person_places;

  DELETE FROM classification_contents;
  DELETE FROM searches;

  DELETE FROM overlays;
  DELETE FROM tags;
  DELETE FROM overlay_place_tags;
eos

delete_content_histories = <<-eos
  DELETE FROM creative_work_histories;
  DELETE FROM creative_work_history_translations;
  DELETE FROM event_histories;
  DELETE FROM event_history_translations;
  DELETE FROM person_histories;
  DELETE FROM person_history_translations;
  DELETE FROM place_histories;
  DELETE FROM place_history_translations;

  DELETE FROM creative_work_event_histories;
  DELETE FROM creative_work_person_histories;
  DELETE FROM creative_work_place_histories;
  DELETE FROM event_person_histories;
  DELETE FROM event_place_histories;
  DELETE FROM person_place_histories;

  DELETE FROM classification_content_histories;
eos


Rake::Task['db:create'].enhance do
  if ENV['RAILS_ENV']
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')
  else
    ActiveRecord::Base.establish_connection(:development)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.establish_connection(:development)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.establish_connection(:development)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')

    ActiveRecord::Base.establish_connection(:test)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.establish_connection(:test)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.establish_connection(:test)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')
  end
end

namespace :data_cycle_core do
  namespace :clear do
    desc "Remove all data except for configuration data like users"
    task :all => :environment do
      ActiveRecord::Base.connection.execute(delete_classifications)
      ActiveRecord::Base.connection.execute(delete_secondary_data)
      ActiveRecord::Base.connection.execute(delete_contents)
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end

    desc "Remove all contents related data like creative works and places (does not remove classifications)"
    task :contents => :environment do
      ActiveRecord::Base.connection.execute(delete_secondary_data)
      ActiveRecord::Base.connection.execute(delete_contents)
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end

    desc "Remove the history of all content data"
    task :history => :environment do
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end
  end

  namespace :import do
    desc "List available endpoints for import"
    task :list => :environment do
      DataCycleCore::ExternalSource.all.each do |external_source|
        puts "#{external_source.id} - #{external_source.name}"
      end
    end

    desc "Download and import data from given data source"
    task :perform, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = Hash[{max_count: FIXNUM_MAX}.merge(args.to_h).map { |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      }]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options)
      external_source.import(options)
    end

    desc "DEBUG: Only download data from given data source"
    task :download, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = Hash[{max_count: nil}.merge(args.to_h).map { |k, v|
        if k == :max_count && v
          [k, v.to_i]
        else
          [k, v]
        end
      }]
      #options[:locales] = [:de] #, :en, :fr, :it, :nl]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options)
    end

    desc "DEBUG: Only import (without downloading) data from given data source"
    task :import, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = Hash[{max_count: FIXNUM_MAX}.merge(args.to_h).map { |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      }]
      #options[:locales] = [:de] #, :fr, :en, :it, :nl]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.import(options)
    end


  end

  namespace :update do

    desc "import classifications"
    task :import_classifications => [:environment] do
      path = Rails.root.join('config','data_definitions','classifications.yml')
      DataCycleCore::MasterData::ImportClassifications.new.import(path.to_s)
    end

    desc "import template definitions"
    task :import_templates => [:environment] do
      path = Rails.root.join('config','data_definitions','creative_works','*.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::CreativeWork)
      path = Rails.root.join('config','data_definitions','places','*.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Place)
      path = Rails.root.join('config','data_definitions','persons','*.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Person)
      path = Rails.root.join('config','data_definitions','events','*.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Event)
    end

    desc "replace the data-definitions of all data-types in the Database with the templates in the Database"
    task :update_all_templates => [:environment] do
      puts "updating templates:"
      DataCycleCore.content_tables.each do |content_table|
        data_object = "DataCycleCore::#{content_table.classify}".safe_constantize
        data_object.where(template: true).each do |template_object|
          template_name = template_object.headline
          data_count = data_object.where(template: false).where("metadata #>> '{validation, name}' = ?", template_name).count
          puts "#{content_table.ljust(25)} | #{template_name.ljust(25)} | #{data_count.to_s.rjust(10)}"

          strategy = DataCycleCore::Update::UpdateTemplate
          DataCycleCore::Update::Update.new(type: data_object, template: template_object, strategy: strategy, transformation: nil)
        end
      end
    end

    desc "update weigths (boost) in search table"
    task :update_search => [:environment] do
      puts "#{'content_class'.ljust(30)} | #{'data_definition_name'.ljust(25)} | #{'#entries'.ljust(10)} | #{'new weight'}"
      puts '-'*84
      DataCycleCore.content_tables.each do |content_table|
        data_object = "DataCycleCore::#{content_table.classify}".safe_constantize
        data_object.where(template: true).each do |template_object|
          template_name = template_object.headline
          boost = template_object.metadata['validation']['boost']

          unless boost.blank?
            search_entries = DataCycleCore::Search.where(content_data_type: data_object.to_s, data_type: template_name).count

            connection = ActiveRecord::Base.connection
            sql_update = "UPDATE searches SET boost = #{boost} WHERE content_data_type = '#{data_object.to_s}' AND data_type = '#{template_name}'"
            connection.exec_query(sql_update)
          end

          puts "#{data_object.to_s.ljust(30)} | #{template_name.ljust(25)} | #{search_entries.to_s.rjust(10)} | #{(boost||'no search').to_s.rjust(10)}"
        end
      end
    end

    desc "replace a given data-definition with its recent template for a content_table"
    task :update_template, [:content_table_name, :template_name] => [:environment] do |t, args|
      unless DataCycleCore.content_tables.include?(args[:content_table_name])
        puts "ERROR: only the following content_table_names are known to the system:"
        puts "#{DataCycleCore.content_tables}"
        exit -1
      end

      data_object = "DataCycleCore::#{args[:content_table_name].classify}".safe_constantize
      template = data_object.find_by(headline: args[:template_name], template: true)

      if template.nil?
        puts "ERROR: template not found. For the given #{args[:content_table_name]} table only the following templates are available:"
        puts data_object.where(template: true).map(&:headline)
        exit -1
      end

      type = data_object
      strategy = DataCycleCore::Update::UpdateTemplate
      transformation = nil

      DataCycleCore::Update::Update.new(type: type, template: template, strategy: strategy, transformation: transformation)
    end


    desc "DEBUG: hook to wire custom data update for a given content_table_name/template_name"
    task :update_data, [:content_table_name, :template_name] => [:environment] do |t, args|
      unless DataCycleCore.content_tables.include?(args[:content_table_name])
        puts "ERROR: only the following content_table_names are known to the system:"
        puts "#{DataCycleCore.content_tables}"
        exit -1
      end

      data_object = "DataCycleCore::#{args[:content_table_name].classify}".safe_constantize
      template = data_object.find_by(headline: args[:template_name], template: true)

      if template.nil?
        puts "ERROR: template not found. For the given #{args[:content_table_name]} table only the following templates are available:"
        puts data_object.where(template: true).map(&:headline)
        exit -1
      end

      type = data_object
      strategy = DataCycleCore::Update::UpdateData
      transformation = nil

      DataCycleCore::Update::Update.new(type: type, template: template, strategy: strategy, transformation: transformation)
    end
  end

  namespace :data_update do
    desc "copy data to content_content(+history) table"
    task :stage1 => [:environment] do

      @connection = ActiveRecord::Base.connection
      data_hash = [
        {a: 'creative_work', type_a: 'DataCycleCore::CreativeWork', relation_a: 'content_location', b: 'place', type_b: 'DataCycleCore::Place'},
        {a: 'creative_work', type_a: 'DataCycleCore::CreativeWork', ralation_a: 'event', b: 'event', type_b: 'DataCycleCore::Event'},
        {a: 'creative_work', type_a: 'DataCycleCore::CreativeWork', relation_a: '', b: 'person', type_b: 'DataCycleCore::Person'}
      ]

      data_hash.each do |item|
        sql_query = <<-eos
          INSERT INTO content_contents
          SELECT
            id,
            #{item[:a]}_id AS content_a_id,
            '#{item[:type_a]}' AS content_a_type,
            '#{item[:relation_a]}' AS relation_a,
            #{item[:b]}_id AS  content_b_id,
            '#{item[:type_b]}' AS content_b_type,
            '' AS relation_b,
            external_source_id,
            created_at,
            updated_at
          FROM #{item[:a]}_#{item[:b].pluralize};
        eos
        @connection.exec_query(sql_query)

        sql_query = <<-eos
          INSERT INTO content_content_histories
          SELECT
            id,
            #{item[:a]}_history_id AS content_a_history_id,
            '#{item[:type_a]}::History' AS content_a_history_type,
            '#{item[:relation_a]}' AS relation_a,
            #{item[:b]}_history_id AS content_b_history_id,
            '#{item[:type_b]}::History' AS content_b_history_type,
            '' AS relation_b,
            external_source_id,
            history_valid,
            created_at,
            updated_at
          FROM #{item[:a]}_#{item[:b]}_histories;
        eos
        @connection.exec_query(sql_query)
      end
    end

    desc "cleanup relation_names in content_content(+history) table"
    task :stage1_1 => [:environment] do

      @connection = ActiveRecord::Base.connection
      parameter_hash = [
        { relation: 'author', template: "= 'Zitat'" },
        { relation: 'person', template: "= 'Interview'" },
        { relation: 'about', template: "IN ('Interview','Portrait')" }
      ]

      parameter_hash.each do |params|
        update = <<-eos
          UPDATE content_contents
          SET relation_a = '#{params[:relation]}'
          FROM creative_works
          WHERE content_contents.content_a_id = creative_works.id
            AND content_contents.content_a_type = 'DataCycleCore::CreativeWork'
            AND content_contents.relation_a = ''
            AND content_contents.content_b_type = 'DataCycleCore::Person'
            AND content_contents.relation_b = ''
            AND creative_works.metadata #>> '{validation,name}' #{params[:template]};
        eos
        @connection.exec_query(update)
        update = <<-eos
          UPDATE content_content_histories
          SET relation_a = '#{params[:relation]}'
          FROM creative_work_histories
          WHERE content_content_histories.content_a_history_id = creative_work_histories.id
            AND content_content_histories.content_a_history_type = 'DataCycleCore::CreativeWork::History'
            AND content_content_histories.relation_a = ''
            AND content_content_histories.content_b_history_type = 'DataCycleCore::Person:History'
            AND content_content_histories.relation_b = ''
            AND creative_work_histories.metadata #>> '{validation,name}' #{params[:template]};
        eos
        @connection.exec_query(update)
      end
    end

    desc "delete data in content_content(+history) table"
    task :undo_stage1 => [:environment] do
      @connection = ActiveRecord::Base.connection
      delete = "DELETE FROM content_contents;"
      @connection.exec_query(delete)
      delete = "DELETE FROM content_content_histories;"
      @connection.exec_query(delete)
    end

    desc "update .._hasPart arrays to content_content relation table"
    task :stage2 => [:environment] do

      array_names = ['question_hasPart','website_hasPart','offer_periods_hasPart',
        'mobile_application_hasPart','quotation_hasPart','accepted_answer_hasPart',
        'suggested_answer_hasPart','timeline_item_hasPart']

      where_string = "metadata ?| array['"+array_names.join("','")+"']"
      DataCycleCore::CreativeWork.where(where_string).each do |item|
        #puts "#{item.id} || #{item.metadata['validation']['name']}"
        array_names.each do |name|
          if item.metadata.has_key?(name)
            #puts "#{name.split('_hasPart')[0]} -> "
            item.metadata[name].each do |content_id|
              DataCycleCore::ContentContent.create!(
                content_a_id: item.id,
                content_a_type: 'DataCycleCore::CreativeWork',
                relation_a: name.split('_hasPart')[0],
                content_b_id: content_id,
                content_b_type: 'DataCycleCore::CreativeWork',
                relation_b: ''
              )
              puts "relation: #{name.split('_hasPart')[0]} | CreativeWork"
            end
            item.metadata = item.metadata.except(name)
            I18n.with_locale(item.available_locales.first){ item.save }
          end
        end
      end

      DataCycleCore::CreativeWork::History.where(where_string).each do |item|
        #puts "#{item.id} || #{item.creative_work_id} || #{item.metadata['validation']['name']}"
        array_names.each do |name|
          if item.metadata.has_key?(name)
            #puts "#{name.split('_hasPart')[0]} -> "
            item.metadata[name].each do |content_id|
              DataCycleCore::ContentContent::History.create!(
                content_a_history_id: item.id,
                content_a_history_type: 'DataCycleCore::CreativeWork::History',
                relation_a: name.split('_hasPart')[0],
                content_b_history_id: content_id,
                content_b_history_type: 'DataCycleCore::CreativeWork::History',
                relation_b: '',
                history_valid: item.history_valid
              )
              puts "relation: #{name.split('_hasPart')[0]} | CreativeWork::History"
            end
            item.metadata = item.metadata.except(name)
            I18n.with_locale(item.available_locales.first){ item.save }
          end
        end
      end

    end

    desc "update ..embeddedLink(Array) to content_content relation table"
    task :stage3 => [:environment] do

      # all embeddedLink(Array) are stored in metadata --> translations irrelevant

      puts "updating embeddedLink and embeddedLinkArray:"
      index = 0
      # DataCycleCore.content_tables.each do |content_table|
      #   content_class = "DataCycleCore::#{content_table.classify}"
      #   puts "updating ==> #{content_class}"
      #   content_class.constantize.all.each do |item|
      #     item.linked_relations.each do |link_definition|
      #       next if item.metadata[link_definition[:name]].blank?
      #       index += 1
      #
      #       values = item.metadata[link_definition[:name]]
      #       uuid_list = link_definition[:type] == 'embeddedLink' ? [ values ] : values
      #
      #       puts "#{index.to_s.rjust(3)}: #{item.id}"
      #       puts "     #{link_definition[:name]}(#{link_definition[:type]}):"
      #       uuid_list.each do |uuid|
      #         puts "     --> #{uuid}"
      #         item_data = [uuid, "DataCycleCore::#{link_definition[:table].classify}", ""]
      #         self_data = [item.id, item.class.to_s, link_definition[:name]]
      #         relation_data = ['a', 'b'].map { |selector|
      #           ["content_#{selector}_id".to_sym, "content_#{selector}_type".to_sym, "relation_#{selector}".to_sym]
      #         }.flatten
      #         .zip(link_definition[:table] < item.class.table_name ? item_data+self_data : self_data+item_data).to_h
      #
      #         DataCycleCore::ContentContent.find_or_create_by!(relation_data)
      #
      #       end
      #
      #       # save without metadata embeddeLink(Array) field
      #       item.metadata = item.metadata.except(link_definition[:name])
      #       I18n.with_locale(item.available_locales.first){ item.save }
      #     end
      #   end
      # end

      DataCycleCore.content_tables.each do |content_table|
        content_class = "DataCycleCore::#{content_table.classify}::History"
        puts "updating ==> #{content_class}"
        content_class.constantize.all.each do |item|
          item.linked_relations.each do |link_definition|
            next if item.metadata[link_definition[:name]].blank?
            index += 1

            values = item.metadata[link_definition[:name]]
            uuid_list = link_definition[:type] == 'embeddedLink' ? [ values ] : values

            puts "#{index.to_s.rjust(3)}: #{item.id}"
            puts "     #{link_definition[:name]}(#{link_definition[:type]}):"
            uuid_list.each do |uuid|
              puts "     --> #{uuid}"
              item_data = [uuid, "DataCycleCore::#{link_definition[:table].classify}", ""]
              self_data = [item.id, item.class.to_s, link_definition[:name]]
              relation_data = ['a', 'b'].map { |selector|
                ["content_#{selector}_history_id".to_sym, "content_#{selector}_history_type".to_sym, "relation_#{selector}".to_sym]
              }.flatten
              .zip(link_definition[:table] < item.class.table_name ? item_data+self_data : self_data+item_data).to_h

              DataCycleCore::ContentContent::History.find_or_create_by!(relation_data)

            end

            # save without metadata embeddeLink(Array) field
            # item.metadata = item.metadata.except(link_definition[:name])
            # I18n.with_locale(item.available_locales.first){ item.save }
          end
        end
      end


    end

  end
end
