# frozen_string_literal: true

module DataCycleCore
  module Content
    module Attributes
      # Defines typed geographic template attributes backed by Geometry associations.
      module GeographicAttributes
        # Custom ActiveModel type that normalizes geographic values to RGeo objects.
        class GeoType < ActiveModel::Type::Value
          # Casts strings or geometry-like inputs into an RGeo geographic object.
          #
          # @param value [Object] Input geometry value.
          # @return [RGeo::Feature::Instance, nil] Parsed geographic value.
          def cast(value)
            DataCycleCore::MasterData::DataConverter.string_to_geographic(value)
          end

          # Serializes a geographic value into normalized WKT for comparisons/storage.
          #
          # @param value [Object] Input geometry value.
          # @return [RGeo::Feature::Instance, nil] Normalized geometry object.
          def serialize(value)
            cast(value)
          end

          # Returns adapter-provided values unchanged.
          #
          # @param value [Object] Raw persisted value.
          # @return [Object] Unmodified value.
          def deserialize(value)
            value
          end
        end

        # Dynamically defines typed geographic attributes for a template subclass.
        #
        # @param klass [Class] Target STI subclass.
        # @param template [DataCycleCore::ThingTemplate] Source template definition.
        # @param geometry_association_name [Symbol] Association used to read/write geometry rows.
        # @param define_setters [Boolean] Whether to define writers. Disabled for read-only
        #   models (e.g. histories), which only expose getters backed by geometry_histories.
        # @return [void]
        def define_geo_attributes_for(klass, template, geometry_association_name: :geometries, define_setters: geometry_association_name == :geometries)
          template.geo_property_names.each do |geo_prop_name|
            define_geo_attribute_for(klass, geo_prop_name, geometry_association_name, define_setters:)
          end
        end

        private

        def define_geo_attribute_for(klass, geo_prop_name, geometry_association_name, define_setters: true)
          geometry_record_method_name = :"#{geo_prop_name}_geometry_record"
          load_attribute_method_name = :"load_#{geo_prop_name}_attribute_from_geometry!"
          changed_method_name = :"#{geo_prop_name}_changed?"
          relation_name = geo_prop_name.to_s

          klass.attribute geo_prop_name, GeoType.new

          klass.define_method(geometry_record_method_name) do
            send(geometry_association_name).detect { |g| g.relation == relation_name }
          end

          klass.define_method(load_attribute_method_name) do
            return if send(changed_method_name)
            return unless self[geo_prop_name].nil?

            self[geo_prop_name] = send(geometry_record_method_name)&.geom
            clear_attribute_change(geo_prop_name)
          end

          klass.define_method(geo_prop_name) do
            send(load_attribute_method_name)
            self[geo_prop_name]
          end

          return unless define_setters

          klass.define_method(:"#{geo_prop_name}=") do |value|
            send(load_attribute_method_name)

            type = type_for_attribute(geo_prop_name)
            normalized_value = type.cast(value)
            current_value = self[geo_prop_name]
            return if type.serialize(current_value) == type.serialize(normalized_value)

            self[geo_prop_name] = normalized_value

            geometry_record = send(geometry_record_method_name)

            if normalized_value.blank?
              geometry_record&.mark_for_destruction
              return
            end

            if geometry_record.present? && !geometry_record.marked_for_destruction?
              geometry_record.geom = normalized_value
            else
              priority = properties_for(geo_prop_name)['priority'].to_i
              send(geometry_association_name).build(
                relation: geo_prop_name,
                geom: normalized_value,
                priority: priority.positive? ? priority : 1
              )
            end
          end
        end
      end
    end
  end
end
