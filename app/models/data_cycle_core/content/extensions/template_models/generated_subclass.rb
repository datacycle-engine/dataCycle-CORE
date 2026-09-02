# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module TemplateModels
        # What every template-generated STI subclass (DataCycleCore::Thing::Poi) carries beyond its
        # root: the root's model name and the becomes! cast primitive. StiSubclasses mixes this in
        # and adds the per-template sti_name and geo attributes when it builds the class.
        module GeneratedSubclass
          extend ActiveSupport::Concern

          class_methods do
            # Reuses the base model name so form builders/routes resolve like the base class.
            delegate :model_name, to: :base_class
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
        end
      end
    end
  end
end
