# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module PropertyHelper
        def property_exists?(property_name, definition = nil)
          definition ||= properties_for(property_name)
          return false if definition.nil?

          yield(definition)
        end

        def plain_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::PLAIN_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def geo_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::ThingTemplateExtensions::PropertyTypes::GEO_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def classification_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::CLASSIFICATION_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def linked_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::LINKED_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def object_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::SIMPLE_OBJECT_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def embedded_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::EMBEDDED_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def schedule_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::SCHEDULE_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def asset_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::ASSET_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def collection_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::COLLECTION_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def oembed_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::OEMBED_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def table_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::TABLE_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def timeseries_property?(property_name, definition = nil)
          property_exists?(property_name, definition) do |prop|
            DataCycleCore::Content::Content::TIMESERIES_PROPERTY_TYPES.include?(prop['type'])
          end
        end

        def virtual_property?(property_name, definition = nil)
          property_exists?(property_name, definition) { |prop| prop.key?('virtual') }
        end
      end
    end
  end
end
