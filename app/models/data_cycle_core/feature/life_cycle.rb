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
          @ordered_classifications ||= DataCycleCore::Classification
            .includes(classification_aliases: :classification_tree_label)
            .where(name: ordered_items(content), classification_aliases: {
              classification_tree_labels: {
                name: tree_label(content)
              }
            })
            .sort_by { |c| ordered_items(content)&.index c.name }
            .map { |c| [c.name, { id: c.id, alias_id: c.primary_classification_alias&.id }] }
            .to_h
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
