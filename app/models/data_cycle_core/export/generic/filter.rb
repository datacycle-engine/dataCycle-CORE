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
          :filter_tree_labels
        ].freeze

        def self.filter(**args)
          filter_endpoints(args) || AVAILABLE_WEBHOOK_FILTERS.all? { |f| send(f, args) }
        end

        def self.filter_endpoints(data:, external_system:, method_name:)
          endpoint_ids = Array.wrap(external_system.export_config_by_filter_key(method_name, 'endpoints'))
          endpoints = DataCycleCore::StoredFilter.where(id: endpoint_ids) if endpoint_ids.present?

          raise 'incompatible filter config (endpoints + specific filters) for webhook detected!' if endpoint_ids.present? &&
                                                                                                     (
                                                                                                       external_system.export_config&.dig(:filter)&.except('endpoints').present? ||
                                                                                                       external_system.export_config&.dig(method_name.to_sym, 'filter')&.except('endpoints').present?
                                                                                                     )

          return false if endpoints.blank?

          endpoints.any? { |e| e.apply.query.exists?(id: data.id) }
        end

        def self.filter_presence(data:, external_system:, method_name:)
          presence_check = external_system.export_config_by_filter_key(method_name, 'presence')
          presence_check = presence_check.is_a?(Hash) ? Array.wrap(presence_check.dig(data&.template_name)) : Array.wrap(presence_check)

          return true if presence_check.blank?

          presence_check.all? { |p| data.try(p).present? }
        end

        def self.filter_template_names(data:, external_system:, method_name:)
          template_names = Array.wrap(external_system.export_config_by_filter_key(method_name, 'template_names'))

          return true if template_names.blank?

          data.template_name.in?(template_names)
        end

        def self.filter_external_system_names(data:, external_system:, method_name:)
          external_system_names = Array.wrap(external_system.export_config_by_filter_key(method_name, 'external_systems'))

          return true if external_system_names.blank?

          data.external_source&.identifier&.in?(external_system_names)
        end

        def self.filter_classifications(data:, external_system:, method_name:)
          classification_ids = Array.wrap(external_system.export_config_by_filter_key(method_name, 'classifications')).map { |f| DataCycleCore::ClassificationAlias.classification_for_tree_with_name(f['tree_label'], f['aliases']) }

          return true if classification_ids.blank?

          classification_ids.all? { |c| data.classifications.map(&:id).include?(c) }
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

          return true if tree_labels.blank?

          tree_labels.all? { |tree_label| tree_label.in?(data_tree_labels) }
        end
      end
    end
  end
end
