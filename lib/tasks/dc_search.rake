# frozen_string_literal: true

namespace :dc do
  namespace :search do
    desc 'rebuild the searches table'
    task :rebuild, [:template_names] => :environment do |_, args|
      temp_time = Time.zone.now
      template_names = args.template_names&.split('|')&.map(&:squish)
      puts 'UPDATING SEARCH ENTRIES'

      query = DataCycleCore::ThingTemplate.where.not(content_type: 'embedded')
      query = query.where(template_name: template_names) if template_names.present?

      query.find_each do |thing_template|
        strategy = DataCycleCore::Update::UpdateSearch
        DataCycleCore::Update::Update.new(type: DataCycleCore::Thing, template: DataCycleCore::Thing.new(thing_template:), strategy:, transformation: nil)
      end

      clean_up_query = DataCycleCore::Search.where(searches: { updated_at: ...temp_time })
      clean_up_query = clean_up_query.where(data_type: template_names) if template_names.present?
      clean_up_count = clean_up_query.delete_all

      puts "REMOVED #{clean_up_count} orphaned entries."
    end

    desc 'recreate dict column in search table'
    task recreate_dicts: :environment do
      tmp = Time.zone.now
      puts 'RECREATING SEARCH DICTIONARIES'
      DataCycleCore::Search.update_all('dict = get_dict(searches.locale)')
      puts "RECREATED #{DataCycleCore::Search.count} SEARCH DICTIONARIES (#{Time.zone.now - tmp} s)"
    end

    desc 'copy slug from thing_translations to searches'
    task migrate_slugs: :environment do
      tmp = Time.zone.now
      puts 'COPYING SLUGS'

      sql = <<-SQL.squish
        UPDATE searches
        SET slug = tt.slug
        FROM thing_translations tt
        WHERE tt.thing_id = searches.content_data_id
          AND tt.locale = searches.locale;
      SQL

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql])
      )

      puts "COPIED #{DataCycleCore::Search.count} SLUGS (#{Time.zone.now - tmp} s)"
    end
  end
end
