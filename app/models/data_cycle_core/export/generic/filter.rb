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

        def self.filter(**args)
          if args[:external_system].export_config_by_filter_key(args[:method_name], 'endpoints').present?
            filter_endpoints(**args)
          else
            AVAILABLE_WEBHOOK_FILTERS.all? { |f| send(f, **args) }
          end
        end

        def self.filter_endpoints(data:, external_system:, method_name:)
          return false if data.try(:embedded?)

          endpoint_ids = Array.wrap(external_system.export_config_by_filter_key(method_name, 'endpoints'))
          endpoints = DataCycleCore::StoredFilter.where(id: endpoint_ids) if endpoint_ids.present?

          return false if endpoints.blank?

          endpoints.any? do |endpoint|
            query = endpoint.apply.query.except(:order)

            next true if query.exists?(id: data)

            if data.depending_contents.exists?
              tmp = query.exists?(id: data.depending_contents)

              next tmp if endpoint.linked_stored_filter.nil?
              next tmp && endpoint.linked_stored_filter.apply.except(:order).exists?(id: data)
            end

            false
          end
        end

        def self.filter_presence(data:, external_system:, method_name:)
          presence_check = external_system.export_config_by_filter_key(method_name, 'presence')
          presence_check = presence_check.is_a?(Hash) ? Array.wrap(presence_check.dig(data&.template_name)) : Array.wrap(presence_check)

          presence_check.present? ? presence_check.all? { |p| data.try(p).present? } : true
        end

        def self.filter_template_names(data:, external_system:, method_name:)
          template_names = Array.wrap(external_system.export_config_by_filter_key(method_name, 'template_names'))

          template_names.present? ? data.template_name.in?(template_names) : true
        end

        def self.filter_external_system_names(data:, external_system:, method_name:)
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
            .map { |f| DataCycleCore::StoredFilter.find(f).apply.query.exists?(id: data.id) }
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
