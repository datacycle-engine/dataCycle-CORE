# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        # [#51643] Companion attributes a machine fills, by naming convention rather than by
        # configuration: <base>_generated next to the editorial <base>, both delivered as the same
        # API field. A template declares only the companion; this extension derives the two rules
        # that make it a companion, so neither can be forgotten in a template:
        #
        #   1. it is only computed while the editorial attribute is empty (an injected
        #      :compute: :condition:, evaluated per locale), and
        #   2. the content is marked with the ArtificialIntelligenceAgent contents of #50050
        #      through the injected 'contributor_generated' property.
        #
        # Same shape as Extensions::Overlay, whose _override/_add/_overlay siblings are derived from
        # a flag the same way - features.generated.generated_for is the durable pointer back to the
        # base attribute, the postfix is only how a companion is recognized in the first place.
        module Generated
          GENERATED_POSTFIX = '_generated'
          CONTRIBUTOR_PROPERTY_KEY = 'contributor'
          # NOTE: ends in the postfix, so it has to be excluded from companion detection below -
          # the mirror image of OVERLAY_PRESENT_PROPERTY_KEY, which had to be named so it does not.
          CONTRIBUTOR_GENERATED_PROPERTY_KEY = 'contributor_generated'
          BLANK_CONDITION_METHOD = 'not_exists?'
          OVERRIDE_OVERLAY_TYPE = 'override'

          # @param properties [ActiveSupport::HashWithIndifferentAccess] the template's properties,
          #   mixins resolved and conditional properties already filtered out
          # @return [ActiveSupport::HashWithIndifferentAccess] the same hash, companions marked and
          #   'contributor_generated' injected once
          def add_generated_properties!(properties)
            companion_keys = generated_companion_keys(properties)

            return properties if companion_keys.blank?

            companion_keys.each do |key|
              base_key = generated_base_key(key)
              blocking_keys = generated_blocking_keys(properties, base_key)

              mark_generated_companion!(properties[key], base_key, blocking_keys)
              add_generated_conditions!(properties[key], blocking_keys)
              defer_generated_compute!(properties[key])
            end

            add_contributor_generated_property!(properties, companion_keys)

            properties
          end

          private

          # A _generated attribute without its base attribute is a config error, not a companion:
          # the API would deliver it under its own key and nothing would ever stop it from
          # overwriting an editorial value, because there is none.
          #
          # @return [Array<String>] the companion keys of this template
          def generated_companion_keys(properties)
            candidates = properties.keys.map(&:to_s) - [CONTRIBUTOR_GENERATED_PROPERTY_KEY]

            candidates.select { |key| key.end_with?(GENERATED_POSTFIX) }.select do |key|
              base_key = generated_base_key(key)
              next true if properties.key?(base_key)

              @errors.push("#{@error_path}.properties.#{key} => base attribute '#{base_key}' missing for the #{GENERATED_POSTFIX} convention")

              false
            end
          end

          def generated_base_key(key)
            key.to_s.delete_suffix(GENERATED_POSTFIX)
          end

          # Content#generated_property_names, #generated_base_property_name and
          # #generated_blocking_property_names read this marker, so nothing downstream has to know
          # the postfix.
          def mark_generated_companion!(prop, base_key, blocking_keys)
            prop['features'] ||= {}
            prop['features'].deep_merge!({ 'generated' => { 'generated_for' => base_key, 'blocked_by' => blocking_keys } })
          end

          # Every editorial attribute that has to be empty for the machine to fill in: the base
          # attribute, and the override an editor writes where the base carries an overlay. Only
          # the override, not the _overlay sibling, although that one is the value the API delivers
          # - it is virtual, so it is computed on read, never written, and a compute conditioned on
          # it could never be scheduled by any save. Its definition is exactly "the override, else
          # the base", so the two writable attributes say the same thing under the AND of
          # Compute::Base#conditions_satisfied?.
          #
          # Selected by Extensions::Overlay's own marker rather than by rebuilding its postfix.
          # Requires add_overlay_properties! to have run, which
          # TemplateTransformer#transform_properties guarantees by its order.
          #
          # @return [Array<String>] base_key, plus its override sibling where there is one
          def generated_blocking_keys(properties, base_key)
            override_keys = properties.select { |_, prop|
              prop&.dig('features', 'overlay', 'overlay_for') == base_key &&
                prop&.dig('features', 'overlay', 'overlay_type') == OVERRIDE_OVERLAY_TYPE
            }.keys.map(&:to_s)

            [base_key] + override_keys
          end

          # The rule holds for every companion, so the injected condition is appended to whatever
          # the template declares rather than replacing it - a companion that also runs only in one
          # language still must not overwrite an editorial value. Re-running the transform (an
          # aggregate template is transformed a second time) must not stack duplicates.
          def add_generated_conditions!(prop, blocking_keys)
            return unless prop.key?('compute')

            conditions = Array.wrap(prop.dig('compute', 'condition')).compact_blank

            missing = blocking_keys.reject { |key| conditions.any? { |c| c['name'] == key && c['method'] == BLANK_CONDITION_METHOD } }

            prop['compute']['condition'] = conditions + missing.map { |key| { 'type' => 'content', 'name' => key, 'method' => BLANK_CONDITION_METHOD } }
          end

          # The injected condition is of :type: content, which Compute::Base#condition_satisfied?
          # resolves against the record - so an inline compute would evaluate it against the value
          # before the save that is running, and generate over an ALT label the editors just typed.
          # Both async and after_save run once the record holds the new value, so the mechanism
          # requires one of them and does not leave the choice to each template.
          def defer_generated_compute!(prop)
            return unless ComputeDeferral.inline?(prop)

            prop['compute']['async'] = true
          end

          # The marking of the whole content, injected once, exactly as
          # Extensions::Overlay#add_overlay_present_property! injects 'overlay_present'.
          #
          # :fallback: false is what lets an empty result actually clear the marking, and the
          # :parameters: - every base and companion key, static from here on - are what make the
          # dependency tracker recompute it when one of them changes.
          #
          # The API append is v4 only: :visible: without 'api' has Extensions::Visible set
          # api.disabled, and the v4 override lifts it just there, because the append transformation
          # is implemented in the v4 partials alone. Under v2/v3 the property would otherwise be
          # delivered as a 'contributorGenerated' key of its own instead of merging into
          # 'contributor'.
          def add_contributor_generated_property!(properties, companion_keys)
            properties[CONTRIBUTOR_GENERATED_PROPERTY_KEY] = {
              'label' => CONTRIBUTOR_GENERATED_PROPERTY_KEY,
              'type' => 'linked',
              'template_name' => [DataCycleCore::AiAgentService::TEMPLATE_NAME],
              'local' => true,
              'visible' => ['show'],
              'position' => ({ 'after' => CONTRIBUTOR_PROPERTY_KEY } if properties.key?(CONTRIBUTOR_PROPERTY_KEY)),
              'api' => {
                'v4' => {
                  'disabled' => false,
                  'transformation' => { 'method' => 'append', 'name' => CONTRIBUTOR_PROPERTY_KEY }
                }
              },
              'compute' => {
                'module' => 'Generated',
                'method' => 'ai_agents',
                'async' => true,
                'fallback' => false,
                'parameters' => companion_keys.flat_map { |key| [generated_base_key(key), key] }.uniq
              }
            }.compact
          end
        end
      end
    end
  end
end
