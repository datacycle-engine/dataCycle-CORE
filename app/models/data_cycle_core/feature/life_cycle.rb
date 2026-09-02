# frozen_string_literal: true

module DataCycleCore
  module Feature
    class LifeCycle < Base
      # Life-cycle stage an archived content is moved back to when no `active_name` is configured.
      DEFAULT_ACTIVE_NAME = 'Aktuell'

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

        def routes_module
          DataCycleCore::Feature::Routes::LifeCycle
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
          configuration(content)['ordered']
        end

        def archive_name(content = nil)
          configuration(content)['archive_name'] || []
        end

        def archive_id(content = nil)
          ordered_classifications(content)&.dig(archive_name(content))&.[](:id)
        end

        # Counterpart of #archive_name: the stage a content belongs in while it is live. Callers that
        # carry their own target (a rake argument, an import option) pass it as `stage_name` instead
        # of resolving stage names themselves.
        #
        # @param stage_name [String, nil] overrides the configured stage when present
        # @return [String] name of the active life-cycle stage
        def active_name(content = nil, stage_name = nil)
          stage_name.presence || configuration(content)['active_name'].presence || DEFAULT_ACTIVE_NAME
        end

        # @return [String, nil] classification id of #active_name, nil when that stage is not part of
        #   the content's configured life cycle
        def active_id(content = nil, stage_name = nil)
          ordered_classifications(content)&.dig(active_name(content, stage_name))&.[](:id)
        end

        def creatable_stages(content = nil)
          ordered_classifications(content)
            .except('Archiv')
            .map { |k, v| [k, v[:id]] }
        end

        def tree_label(content = nil)
          configuration(content)['tree_label']
        end

        def default_alias_id(content)
          ordered_classifications(content).presence&.dig(content&.schema&.dig('properties', allowed_attribute_keys(content)&.first, 'default_value'), :id)
        end
      end
    end
  end
end
