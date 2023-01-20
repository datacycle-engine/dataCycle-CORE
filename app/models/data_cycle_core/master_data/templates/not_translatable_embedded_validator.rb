# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class NotTranslatableEmbeddedValidator
        attr_reader :errors

        def initialize
          @errors = []
          @template_names = []
        end

        def valid?
          @errors.blank?
        end

        def validate
          load_not_translatable!
          return [] if @template_names.blank?

          DataCycleCore::Thing.where(template: true).find_each do |template|
            template.embedded_property_names.map { |item|
              { item => template.properties_for(item) }
            }.each do |properties|
              key = properties.keys.first
              next unless properties.dig(key, 'template_name').in?(@template_names)
              next if properties.dig(key, 'translated') == true

              @errors.push("#{template.template_name}.#{key}")
            end
          end
        end

        def load_not_translatable!
          DataCycleCore::Thing.where(template: true).find_each do |template|
            properties = template.schema['properties'].with_indifferent_access
            @template_names.push(template.template_name) if not_translatable?(properties)
          end
        end

        def not_translatable?(properties)
          translated_columns = DataCycleCore::Thing.new.translated_attributes
          result = true
          properties.each do |name, property|
            next if property.dig(:type).in? [:key, :classification, :asset, :linked, :embedded]
            return false if property[:storage_location] == 'translated_value'
            return false if property[:storage_location] == 'column' && name.in?(translated_columns)
            result = not_translatable?(property.dig(:properties)) if property.dig(:type) == :object
            return false if result == false
          end
          true
        end
      end
    end
  end
end
