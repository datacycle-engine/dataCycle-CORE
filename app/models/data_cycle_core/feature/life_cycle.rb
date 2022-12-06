# frozen_string_literal: true

module DataCycleCore
  module Feature
    class LifeCycle < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::LifeCycle
        end

        def data_hash_module
          DataCycleCore::Feature::DataHash::LifeCycle
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::LifeCycle
        end

        def ordered_classifications(content = nil)
          @ordered_classifications ||= DataCycleCore::ClassificationAlias
            .joins(:primary_classification)
            .for_tree(tree_label(content))
            .with_internal_name(ordered_items(content))
            .order(
              [
                Arel.sql('array_position(ARRAY[?]::VARCHAR[], classification_aliases.internal_name)'),
                ordered_items(content)
              ]
            )
            .pluck(
              Arel.sql("classification_aliases.internal_name, jsonb_build_object('id', classifications.id, 'alias_id', classification_aliases.id)")
            ).to_h.with_indifferent_access
        end

        def ordered_items(content = nil)
          configuration(content).dig('ordered')
        end

        def creatable_stages(content = nil)
          ordered_classifications(content)
            .except('Archiv')
            .map { |k, v| [k, v[:id]] }
        end

        def tree_label(content = nil)
          configuration(content).dig('tree_label')
        end

        def default_alias_id(content)
          ordered_classifications(content).presence&.dig(content&.schema&.dig('properties', allowed_attribute_keys(content)&.first, 'default_value'), :id)
        end

        def data_attribute(content)
          DataCycleCore::DataAttribute.new(attribute_keys.first, content&.properties_for(attribute_keys.first) || {}, {}, content, :show)
        end
      end
    end
  end
end
