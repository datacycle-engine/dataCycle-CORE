# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      # Template-backed models: one STI subclass per ThingTemplate, and a record whose
      # template-driven attributes (boost/content_type/cache_valid_since) follow the template
      # assigned to it.
      #
      # This concern is the record side of that — assigning template_name/thing_template resyncs
      # them. The class side is split off:
      #
      #   * StiSubclasses    - generating the per-template subclasses and resolving to them
      #   * GeneratedSubclass - what each generated subclass carries (becomes!, model_name)
      #
      # The setter methods for properties should not be used yet, as they will not trigger the
      # necessary callbacks; use set_data_hash for updating properties instead.
      #
      # The import-driven in-place type conversion built on top of the becomes! cast primitive
      # (can_become?/update_template!/obsolete-attribute cleanup) lives in the companion concern
      # TemplateConversion.
      module TemplateModels
        extend ActiveSupport::Concern

        include StiSubclasses

        delegate :sti_class_for, to: :class

        # Assigns the template identifier and synchronizes template-driven
        # properties when the assigned value changes on persisted records.
        #
        # @param value [String, nil] Template identifier.
        # @return [String, nil]
        def template_name=(value)
          super

          return if new_record? || !template_name_changed?

          validate_template!
          update_template_properties
        end

        # Assigns a template object, updates the underlying template identifier,
        # and synchronizes template-driven properties when the template changes
        # on persisted records.
        #
        # @param value [DataCycleCore::ThingTemplate, nil] Template object.
        # @return [DataCycleCore::ThingTemplate, nil]
        def thing_template=(value)
          super

          return if new_record? || !template_name_changed?

          validate_template!
          self.template_name = value.template_name
          update_template_properties
        end

        # Reloads the template definition and copies its derived attributes onto
        # the current record.
        #
        # @return [void]
        def update_template_properties
          reload_template_definition

          self.boost = thing_template.boost
          self.content_type = thing_template.content_type
          self.cache_valid_since = Time.current
        end
      end
    end
  end
end
