# frozen_string_literal: true

class CleanupHelper
  class << self
    def identify_external_source(item)
      return nil if item.config.blank?
      item.config['download_config'].first[1]['endpoint'].split('::')[-2]
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
      }[external_source]
      return if core_data_templates.blank?
      core_data_templates&.map { |template|
        thing_template = DataCycleCore::Thing.new(template_name: template)
        thing_template.linked_property_names.map do |linked_item|
          properties = thing_template.properties_for(linked_item)
          if properties['template_name'].present?
            { relation: linked_item, template: properties['template_name'] }
          elsif properties['stored_filter'].present?
            properties['stored_filter'].first.dig('with_classification_aliases_and_treename', 'aliases').map do |item|
              { relation: linked_item, template: item }
            end
          end
        end
      }&.flatten&.uniq
    end

    def embedded
      embedded_hash = {}
      DataCycleCore::ThingTemplate.where(content_type: 'entity').map do |main_thing_temp|
        main_temp = DataCycleCore::Thing.new(thing_template: main_thing_temp)
        main_temp.embedded_property_names.map do |embedded_item|
          properties = main_temp.properties_for(embedded_item)
          if embedded_hash.key?(properties['template_name'])
            embedded_hash[properties['template_name']].push(main_temp.template_name)
          else
            embedded_hash[properties['template_name']] = [main_temp.template_name]
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
          WHERE things.template_name = '#{embedded_name}'
          AND things2.template_name IN (#{template_string})
        )
      SQL

      DataCycleCore::Thing.where(template_name: embedded_name).where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, where_string))
    end
  end
end
