# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      # [#51643] When a compute writes its value, relative to the save that scheduled it. The
      # declaration is two optional flags, so the classification only exists once it is read as an
      # order: Content's three computed-property selectors, TemplateValidator
      # #validate_compute_deferral_order! and Extensions::Generated#defer_generated_compute! all
      # read it here, so adding a deferral or renaming a flag is one edit.
      module ComputeDeferral
        # Earliest first: the inline pass during DataHash#before_save_data_hash, compute.after_save
        # once the save is written (Extensions::ComputedValue#update_after_save_computed_values),
        # compute.async in a later UpdateAsyncComputedPropertiesJob.
        ORDER = ['inline', 'after_save', 'async'].freeze

        class << self
          # @param definition [Hash, nil] a property definition
          # @return [String, nil] the ORDER entry the property's compute runs in, nil without one
          def of(definition)
            return unless definition.is_a?(::Hash) && definition.key?('compute')
            return 'async' if flag?(definition, 'async')
            return 'after_save' if flag?(definition, 'after_save')

            'inline'
          end

          # @return [Boolean] whether the property is computed by the inline before_save pass
          def inline?(definition)
            of(definition) == 'inline'
          end

          # @return [Boolean] whether the property is computed after the save, in the same request
          def after_save?(definition)
            of(definition) == 'after_save'
          end

          # @return [Boolean] whether the property is computed by a later background job
          def async?(definition)
            of(definition) == 'async'
          end

          # @param definition [Hash, nil] the depending property's definition
          # @param parameter_definition [Hash, nil] the definition of a property it names in
          #   :parameters:
          # @return [Boolean] whether the parameter is computed after the compute that reads it.
          #   False for a parameter carrying no compute at all: a plain attribute is always
          #   readable and a :virtual: one is derived on read, so neither can be too late.
          def later?(parameter_definition, than:)
            own = of(than)
            parameter = of(parameter_definition)
            return false if own.nil? || parameter.nil?

            ORDER.index(parameter) > ORDER.index(own)
          end

          private

          def flag?(definition, key)
            definition.dig('compute', key).to_s == 'true'
          end
        end
      end
    end
  end
end
