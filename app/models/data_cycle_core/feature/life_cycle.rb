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
          @ordered_classifications ||= Hash.new do |h, k|
            h[k] = DataCycleCore::ClassificationAlias
              .joins(:primary_classification)
              .for_tree(k[0])
              .by_ordered_values(k[1], :internal_name)
              .pluck(
                Arel.sql("classification_aliases.internal_name, json_build_object('id', classifications.id, 'alias_id', classification_aliases.id)")
              ).to_h.with_indifferent_access
          end

          @ordered_classifications[[tree_label(content), ordered_items(content)]]
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
