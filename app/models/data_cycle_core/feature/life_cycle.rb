# frozen_string_literal: true

module DataCycleCore
  module Feature
    class LifeCycle < Base
      class << self
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

        def tree_label(content = nil)
          configuration(content).dig('tree_label')
        end

        def default_filter(content = nil)
          configuration(content).dig('default_filter')
        end

        def controller_functions
          ['update_life_cycle_stage']
        end
      end
    end
  end
end
