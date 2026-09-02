# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Filter
        AVAILABLE_WEBHOOK_FILTERS = [
          :filter_presence,
          :filter_template_names,
          :filter_external_system_names,
          :filter_classifications,
          :filter_tree_labels,
          :filter_watch_lists,
          :filter_stored_filters
        ].freeze

        # A delete asks whether the receiver still holds the content, which none of the filters below
        # answer: gating it on current containment leaves everything an earlier, wider filter
        # exported behind at the receiver for good, since narrowing the filter is exactly what takes
        # a content out of it. What was exported gets deleted.
        def self.filter(**args)
          return exported?(args[:data], args[:external_system]) if args[:method_name].to_s.end_with?('delete')

          if endpoint_ids_for(args[:external_system], args[:method_name]).present?
            filter_endpoints(**args)
          else
            AVAILABLE_WEBHOOK_FILTERS.all? { |f| send(f, **args) }
          end
        end

        # Per record over the polymorphic association rather than DataCycleCore::Thing.delivered_to:
        # export_config.allowed_models admits any syncable, DataCycleCore::User among them.
        def self.exported?(data, external_system)
          data.external_system_syncs.delivered_to(external_system).exists?
        end

        # Only contents an endpoint contains itself are exported; being linked from such a content is
        # explicitly not enough (DataCycleCore::Export::RelatedWebhooks).
        def self.filter_endpoints(data:, external_system:, method_name:)
          return false if data.try(:embedded?)

          endpoints = endpoints_for(external_system, method_name)

          return false if endpoints.blank?

          endpoints.any? { |endpoint| endpoint_things(endpoint).exists?(id: data.id) }
        end

        # The ids as configured, before by_id_or_slug drops the ones that resolve to nothing: the
        # guards in DataCycleCore::Export::StaleCleanup report on the difference between the two, and
        # a second reading of the config is what would let their two halves drift apart.
        def self.endpoint_ids_for(external_system, method_name)
          Array.wrap(external_system.export_config_by_filter_key(method_name, 'endpoints')).uniq
        end

        def self.endpoints_for(external_system, method_name)
          endpoint_ids = endpoint_ids_for(external_system, method_name)

          return if endpoint_ids.blank?

          DataCycleCore::StoredFilter.by_id_or_slug(endpoint_ids)
        end

        # What an endpoint contains, for the filter above and for the candidates
        # DataCycleCore::Export::RelatedWebhooks narrows to before enqueueing: the two decide the same
        # question at either end of a job and fall apart silently if they read different sets.
        # DataCycleCore::Export::StaleCleanup deliberately reads wider — see #endpoint_things_all_locales.
        def self.endpoint_things(endpoint)
          endpoint.unsorted_things
        end

        def self.filter_presence(data:, external_system:, method_name:)
          presence_check = external_system.export_config_by_filter_key(method_name, 'presence')
          presence_check = presence_check.is_a?(Hash) ? Array.wrap(presence_check[data&.template_name]) : Array.wrap(presence_check)

          presence_check.present? ? presence_check.all? { |p| data.try(p).present? } : true
        end

        def self.filter_template_names(data:, external_system:, method_name:) # rubocop:disable Naming/PredicateMethod
          template_names = Array.wrap(external_system.export_config_by_filter_key(method_name, 'template_names'))

          template_names.present? ? data.template_name.in?(template_names) : true
        end

        def self.filter_external_system_names(data:, external_system:, method_name:) # rubocop:disable Naming/PredicateMethod
          external_system_names = Array.wrap(external_system.export_config_by_filter_key(method_name, 'external_systems'))

          external_system_names.present? ? data.external_source&.identifier&.in?(external_system_names) : true
        end

        def self.filter_classifications(data:, external_system:, method_name:)
          classification_ids = Array.wrap(external_system.export_config_by_filter_key(method_name, 'classifications')).map { |f| DataCycleCore::ClassificationAlias.classification_for_tree_with_name(f['tree_label'], f['aliases']) }

          classification_ids.present? ? classification_ids.all? { |c| data.classifications.map(&:id).include?(c) } : true
        end

        def self.filter_watch_lists(data:, external_system:, method_name:)
          filter_conf = external_system.export_config_by_filter_key(method_name, 'watch_lists')
          return true if filter_conf.blank?

          Array.wrap(filter_conf)
            .map { |f| DataCycleCore::WatchList.find(f).things.exists?(id: data.id) }
            .reduce(&:|)
        end

        # use preferably filter_endpoints
        def self.filter_stored_filters(data:, external_system:, method_name:)
          filter_conf = external_system.export_config_by_filter_key(method_name, 'stored_filters')
          return true if filter_conf.blank?

          Array.wrap(filter_conf)
            .map { |f| DataCycleCore::StoredFilter.by_id_or_slug(f).first!&.things&.exists?(id: data.id) }
            .reduce(&:|)
        end

        def self.filter_tree_labels(data:, external_system:, method_name:)
          tree_labels = Array.wrap(external_system.export_config_by_filter_key(method_name, 'tree_labels'))

          if tree_labels.present?
            data_tree_labels = data
              .classifications
              .classification_aliases
              .map(&:classification_tree_label)
              .pluck(:name)
              .uniq
          end

          tree_labels.present? ? tree_labels.all? { |tree_label| tree_label.in?(data_tree_labels) } : true
        end
      end
    end
  end
end
