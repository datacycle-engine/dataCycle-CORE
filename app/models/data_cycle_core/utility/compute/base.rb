# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Base
        class << self
          def compute_values(key, data_hash, content, current_user = nil, force = false)
            return if data_hash.key?(key)

            properties = content.properties_for(key)&.with_indifferent_access

            return unless properties&.key?('compute')
            return unless conditions_satisfied?(content, properties, current_user)

            computed_parameters = parameter_keys(content, properties)
            computed_value_hash = data_hash.dc_deep_dup

            return if skip_compute_value?(key, computed_value_hash, content, computed_parameters, false, current_user, force)

            method_name = DataCycleCore::ModuleService
              .load_module(properties.dig('compute', 'module').classify, 'Utility::Compute')
              .method(properties.dig('compute', 'method'))

            data_hash[key] = method_name.call(
              computed_parameters: computed_parameters.index_with { |v| computed_value_hash[v] },
              key:,
              data_hash: computed_value_hash,
              content:,
              computed_definition: properties,
              current_user:
            )

            # keep fallback for imported computed values
            data_hash[key] = content.attribute_to_h(key) if DataCycleCore::DataHashService.blank?(data_hash[key]) && properties.dig('compute', 'fallback').to_s != 'false'
          end

          def parameter_keys(content, properties)
            Array.wrap(properties&.dig('compute', 'parameters'))
              .map { |p| p.split('.').first }
              .uniq
              .intersection(content.property_names)
          end

          def conditions_satisfied?(content, properties, current_user)
            return true unless properties['compute'].key?('condition')

            Array.wrap(properties.dig('compute', 'condition')).compact_blank.each do |condition|
              return false unless condition_satisfied?(content, condition, current_user)
            end

            true
          end

          def condition_satisfied?(content, definition, current_user)
            expected_value = definition['value']

            value = case definition['type']
                    when 'external_source'
                      content&.external_source&.default_options&.dig(definition['name'])
                    when 'I18n'
                      I18n.send(definition['name'])
                    when 'content'
                      definition['name']&.split('.')&.inject(content, &:try)
                    when 'current_user'
                      allowed_methods = ['present?', 'nil?']
                      raise 'unknown method for current_user' unless allowed_methods.include?(definition['name'])

                      current_user.try(definition['name'])
                    else
                      raise 'Unknown type for validation'
                    end

            send(definition['method'], value, expected_value)
          end

          # @param missing_keys [Array<String>] parameters of a compute that carry no value yet
          # @param computed_key [String] the compute those parameters belong to
          def load_missing_values(missing_keys, content, datahash, current_user, computed_key)
            missing_keys.each do |missing_key|
              if computed_by_this_pass?(content, missing_key, computed_key)
                compute_values(missing_key, datahash, content, current_user, true)
                datahash[missing_key] = content.attribute_to_h(missing_key) if !datahash.key?(missing_key) && condition_blocked?(content, missing_key, current_user)
              else
                datahash[missing_key] = content.attribute_to_h(missing_key)
              end
            end
          end

          # Which pass is running is read off the compute that is running: a parameter sharing its
          # ComputeDeferral is computed by the same pass, and nothing else has stored it yet. On a
          # create nothing is stored at all, so an inline compute reading another inline one has to
          # run it, and the async job reading a second async property likewise.
          #
          # From a later pass it is waste and a second answer. DataHash#set_data_hash has stored
          # the inline values before the compute.after_save pass runs and before the
          # UpdateAsyncComputedPropertiesJob is enqueued, so the record already carries what the
          # parameter is worth; recomputing it asks a producer reached over the network - the
          # vision service behind a _generated companion - for an answer that is then dropped with
          # the computed_value_hash dup #compute_values nests it in, and the value the reading
          # compute stores is derived from an answer no attribute of the record ever holds.
          #
          # @return [Boolean] whether missing_key still has to be computed rather than read
          def computed_by_this_pass?(content, missing_key, computed_key)
            return false unless content.computed_property_names.include?(missing_key)

            deferral_of(content, missing_key) == deferral_of(content, computed_key)
          end

          # @return [String, nil] the ComputeDeferral of a property of this content
          def deferral_of(content, key)
            DataCycleCore::MasterData::Templates::ComputeDeferral.of(content.properties_for(key))
          end

          # A nested compute that declined because of its own :condition: still owes the depending
          # compute a value, and the one it has is what it stored the last time the condition did
          # hold: that is what lets 'contributor_generated' recompute and drop the AI agent of a
          # 'description_generated' an editorial description has replaced.
          #
          # Only that case. A nested compute #skip_compute_value? itself declined - because its own
          # parameters could not be resolved - leaves the key missing, so the recursion below
          # reports it and the depending compute is skipped rather than run against a stale value.
          #
          # @return [Boolean] true for a computed key whose :condition: forbids computing it now
          def condition_blocked?(content, key, current_user = nil)
            properties = content.properties_for(key)&.with_indifferent_access

            return false unless properties&.key?('compute')

            !conditions_satisfied?(content, properties, current_user)
          end

          def skip_compute_value?(key, datahash, content, computed_parameters, checked = false, current_user = nil, force = false)
            return false if computed_parameters.blank?

            missing_keys = computed_parameters.difference(datahash.slice(*computed_parameters).keys)

            return false if missing_keys.blank?
            return true if checked && missing_keys.present?
            return true if !force && !datahash.keys.intersect?(content.flat_computed_parameters(key, datahash, true))

            load_missing_values(missing_keys, content, datahash, current_user, key)

            skip_compute_value?(key, datahash, content, computed_parameters, true, current_user)
          end

          def equals?(value_a, value_b)
            value_a == value_b
          end

          def exists?(value_a, _value_b)
            value_a.present?
          end

          # Named not_exists? rather than blank?: #condition_satisfied? dispatches the configured
          # :method: with send on this module, so a two-argument blank? would override
          # ActiveSupport's Object#blank? for Utility::Compute::Base itself.
          def not_exists?(value_a, _value_b)
            value_a.blank?
          end
        end
      end
    end
  end
end
