# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      # STI subclass generation + becomes! cast primitive
      #
      # Adds template-based STI subclass generation for Thing models.
      # The setter methods for properties should not be used yet, as they will not trigger the necessary callbacks
      # use set_data_hash for updating properties instead, which will trigger the necessary callbacks
      #
      # This concern owns the STI machinery: per-template subclass generation, the becomes! cast
      # primitive, and keeping template-driven attributes (boost/content_type/cache_valid_since) in sync.
      # The import-driven in-place type conversion built on top of it (can_become?/update_template!/
      # obsolete-attribute cleanup) lives in the companion concern TemplateConversion.
      module TemplateModels
        extend ActiveSupport::Concern

        included do
          self.inheritance_column = :template_name
          self.store_full_sti_class = false
        end

        class_methods do
          include Attributes::GeographicAttributes

          # :nodoc:
          def ensure_sti_subclasses_initialized_once!
            return unless sti_root_class?
            return unless @sti_subclasses_initialized.nil?
            return unless thing_templates_available?

            @sti_subclasses_initialized = {}
            create_sti_subclasses_from_thing_templates!
          end

          # :nodoc:
          def create_sti_subclasses_from_thing_templates!
            DataCycleCore::ThingTemplate.find_each do |template|
              create_sti_subclass_for_template_if_missing!(template)
            end
          end

          # :nodoc:
          def create_sti_subclass_for_template_if_missing!(template)
            base_class = self
            subclass_name = sti_subclass_name_for(template.template_name)
            template_name = template.template_name.to_s
            return if subclass_name.blank? || base_class.const_defined?(subclass_name, false)

            subclass = Class.new(base_class) do
              # Reuses the base model name so form builders/routes resolve like the base class.
              #
              # @return [ActiveModel::Name] Base model naming metadata.
              def self.model_name
                base_class.model_name
              end

              # Casts the current record into another template-backed STI subclass and
              # refreshes template-driven attributes.
              #
              # This is the pure cast PRIMITIVE: a plain ActiveRecord becomes! that returns a NEW,
              # UNSAVED instance of the target subclass and runs no feasibility/domain checks. It does
              # not persist and does not run the obsolete-attribute cleanup. The import-facing
              # TemplateConversion#update_template! is the gated, persisting wrapper around it.
              #
              # @param target_klass [Class, String, Symbol] Target STI class or identifier.
              # @return [DataCycleCore::Thing] The casted record.
              def becomes!(target_klass = self.class)
                target_klass = sti_class_for(target_klass.to_s) if target_klass.is_a?(String) ||
                                                                   target_klass.is_a?(Symbol)

                return self if target_klass == self.class

                became = super
                became.validate_template!
                became.update_template_properties
                became
              end

              define_singleton_method(:sti_name) { template_name }
            end

            geometry_association_name = geometry_association_name_for(base_class)
            define_geo_attributes_for(subclass, template, geometry_association_name:)
            base_class.const_set(subclass_name, subclass)
            @sti_subclasses_initialized[template.template_name] = true
          end

          # Builds the STI subclass for a stored template value on demand when it was
          # not generated during the one-time bulk init — e.g. a ThingTemplate created
          # after init (common in tests, and runtime template imports outside
          # development, where no code reload is triggered).
          #
          # @param type_name [String, Symbol, nil] Raw STI value from persistence.
          # @return [void]
          def create_sti_subclass_for_type_if_missing!(type_name)
            return unless sti_root_class?

            subclass_name = sti_subclass_name_for(type_name)
            return if subclass_name.blank? || const_defined?(subclass_name, false)

            template = DataCycleCore::ThingTemplate.find_by(template_name: type_name.to_s)
            create_sti_subclass_for_template_if_missing!(template) if template.present?
          end

          # Resolves the concrete STI class name for the stored template value.
          #
          # Synthetic / one-shot templates (no persisted ThingTemplate — e.g. the
          # bulk-edit "Generic" aggregate, or a stored value whose template was
          # deleted) generate no STI subclass. They resolve to the base class
          # instead of letting AR's compute_type walk the module nesting and pick
          # up an unrelated constant (e.g. the DataCycleCore::Generic importer
          # module), which AR would then reject with SubclassNotFound.
          #
          # @param type_name [String, Symbol, nil] Raw STI value from persistence.
          # @return [Class] Resolved STI class.
          def sti_class_for(type_name)
            ensure_sti_subclasses_initialized_once!
            create_sti_subclass_for_type_if_missing!(type_name)

            subclass_name = sti_subclass_name_for(type_name)
            return base_class unless subclass_name.present? && base_class.const_defined?(subclass_name, false)

            super(subclass_name)
          end

          # Resolves missing STI subclass constants on first direct constant access.
          #
          # @param const_name [Symbol] Missing constant name.
          # @return [Class] Resolved subclass when available.
          def const_missing(const_name)
            ensure_sti_subclasses_initialized_once!
            return const_get(const_name, false) if const_defined?(const_name, false)

            super
          end

          private

          def sti_subclass_name_for(template_name)
            # camelize (not classify) so plural-ish template names are not singularized,
            # which would mangle names and risk constant collisions. underscore_blanks
            # already strips blanks, so the camelized result has no spaces.
            template_name.to_s.underscore_blanks.camelize
          end

          def sti_root_class?
            self == base_class
          end

          def thing_templates_available?
            DataCycleCore::ThingTemplate.table_exists?
          rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
            false
          end

          def geometry_association_name_for(base_class)
            return :geometries if base_class.reflect_on_association(:geometries).present?
            return :geometry_histories if base_class.reflect_on_association(:geometry_histories).present?

            nil
          end
        end

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
