# frozen_string_literal: true

module DataCycleCore
  module Content
    module Attributes
      # Defines typed classification template attributes backed by the concept_contents association.
      #
      # Mirrors GeographicAttributes for the write side: the attribute value is the sorted list of
      # concept ids, the association rows are built / marked for destruction in memory, and the
      # Thing's own save persists them through autosave.
      #
      # The read side differs from geo: while the attribute is unchanged, the getter stays on the
      # memoized query path (Content#get_property_value -> ContentLoader#load_classifications) instead
      # of caching the ids. Other instances write the same rows - UpdateTemplateDefaultsJob loads its
      # own Thing.find(id) and sets data_type/schema_types there - and a cached value on this instance
      # would not see that until reload. Only once assigned does the in-memory value win.
      module ClassificationAttributes
        # Custom ActiveModel type that normalizes classification input to a sorted list of concept ids.
        class ClassificationType < ActiveModel::Type::Value
          # Casts ids, Concept records, relations or mixed arrays into sorted unique ids.
          # Sorting here is what makes the dirty tracking order-independent: AR compares the
          # cast values with ==, so [b, a] and [a, b] read as the same value.
          #
          # @param value [String, DataCycleCore::Concept, Array, ActiveRecord::Relation, nil] Input value.
          # @return [Array<String>] Sorted unique concept ids.
          def cast(value)
            Array.wrap(value)
              .filter_map { |v| v.is_a?(DataCycleCore::Concept) ? v.id : v.presence }
              .uniq
              .sort
          end

          # Serializes to the same comparable form as cast.
          #
          # @param value [Object] Input value.
          # @return [Array<String>] Sorted unique concept ids.
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

        # Dynamically defines typed classification attributes for a template subclass.
        #
        # @param klass [Class] Target STI subclass.
        # @param template [DataCycleCore::ThingTemplate] Source template definition.
        # @param define_setters [Boolean] Whether to define writers. Disabled for read-only
        #   models (e.g. histories), which have no concept_contents to write to.
        # @return [void]
        def define_classification_attributes_for(klass, template, define_setters: klass.reflect_on_association(:concept_contents).present?)
          template.classification_property_names.each do |prop_name|
            define_classification_attribute_for(klass, prop_name, define_setters:)
          end
        end

        private

        def define_classification_attribute_for(klass, prop_name, define_setters: true)
          records_method_name = :"#{prop_name}_concept_records"
          load_attribute_method_name = :"load_#{prop_name}_attribute_from_concept_contents!"
          changed_method_name = :"#{prop_name}_changed?"
          relation_name = prop_name.to_s

          klass.attribute prop_name, ClassificationType.new

          # A relation rather than the records, so Concept scopes stay chainable on an assigned value
          # the way they are on the loader's - and so Concept.default_scope orders an assigned value
          # the same way it orders the loader's.
          klass.define_method(prop_name) do
            return get_property_value(prop_name, properties_for(prop_name)) unless send(changed_method_name)

            DataCycleCore::Concept.where(id: self[prop_name])
          end

          return unless define_setters

          klass.define_method(records_method_name) do
            concept_contents.select { |cc| cc.relation == relation_name }
          end

          # nil marks "not loaded yet": every assignment goes through cast, so a loaded but empty
          # value is [] and never nil
          klass.define_method(load_attribute_method_name) do
            return if send(changed_method_name)
            return unless self[prop_name].nil?

            self[prop_name] = send(records_method_name).reject(&:marked_for_destruction?).map(&:concept_id)
            clear_attribute_change(prop_name)
          end

          klass.define_method(:"#{prop_name}=") do |value|
            send(load_attribute_method_name)

            new_ids = type_for_attribute(prop_name).cast(value)
            return if self[prop_name] == new_ids

            self[prop_name] = new_ids

            records = send(records_method_name)
            records.each { |cc| cc.mark_for_destruction if new_ids.exclude?(cc.concept_id) }

            kept_ids = records.reject(&:marked_for_destruction?).map(&:concept_id)
            (new_ids - kept_ids).each do |concept_id|
              concept_contents.build(concept_id:, relation: relation_name)
            end
          end
        end
      end
    end
  end
end
