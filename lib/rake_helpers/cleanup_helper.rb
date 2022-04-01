# frozen_string_literal: true

class CleanupHelper
  class << self
    def identify_external_source(item)
      return nil if item.config.blank?
      item.config.dig('download_config').first[1].dig('endpoint').split('::')[-2]
    end

    def linked(external_source)
      core_data_templates = {
        'Booking' => ['Unterkunft'],
        'EventDatabase' => ['Event'],
        'Feratel' => ['Event', 'POI', 'Unterkunft'],
        'MediaArchive' => ['Bild', 'Video'],
        'OutdoorActive' => ['POI', 'Tour'],
        'VTicket' => ['Event'],
        'Xamoom' => ['Örtlichkeit']
      }.dig(external_source)
      return if core_data_templates.blank?
      core_data_templates&.map { |template|
        thing_template = DataCycleCore::Thing.find_by(template_name: template, template: true)
        thing_template.linked_property_names.map do |linked_item|
          properties = thing_template.properties_for(linked_item)
          if properties.dig('template_name').present?
            { relation: linked_item, template: properties.dig('template_name') }
          elsif properties.dig('stored_filter').present?
            properties.dig('stored_filter').first.dig('with_classification_aliases_and_treename', 'aliases').map do |item|
              { relation: linked_item, template: item }
            end
          end
        end
      }&.flatten&.uniq
    end

    def embedded
      embedded_hash = {}
      DataCycleCore::Thing.where(template: true).find_each.select { |temp| temp.content_type == 'entity' }.map do |main_temp|
        main_temp.embedded_property_names.map do |embedded_item|
          properties = main_temp.properties_for(embedded_item)
          if embedded_hash.key?(properties.dig('template_name'))
            embedded_hash[properties.dig('template_name')].push(main_temp.template_name)
          else
            embedded_hash[properties.dig('template_name')] = [main_temp.template_name]
          end
        end
      end
      embedded_hash.map { |key, value| { key => value.uniq } }.reduce({}, &:merge)
    end

    def orphaned_embedded(template_array, embedded_name)
      template_string = "'" + template_array.map(&:to_s).join("', '") + "'"
      where_string = <<-SQL.squish
        things.id NOT IN (
          SELECT things.id FROM things
          INNER JOIN content_contents ON content_contents.content_b_id = things.id
          INNER JOIN things things2 ON content_contents.content_a_id = things2.id
          WHERE things.template = false
          AND things.template_name = '#{embedded_name}'
          AND things2.template = false
          AND things2.template_name IN (#{template_string})
        )
      SQL

      DataCycleCore::Thing.where(template: false, template_name: embedded_name).where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, where_string))
    end
  end
end
