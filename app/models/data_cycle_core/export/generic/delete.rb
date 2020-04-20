# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Delete
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?

          Functions.delete(utility_object: utility_object, data: data)
        end

        def self.filter(data, external_system)
          template_names = Array.wrap(external_system.config.dig('push_config', name.demodulize.underscore, 'filter', 'template_names') || external_system.config.dig('push_config', 'filter', 'template_names'))
          classification_ids = Array.wrap(external_system.config.dig('push_config', name.demodulize.underscore, 'filter', 'classifications') || external_system.config.dig('push_config', 'filter', 'classifications')).map { |f| DataCycleCore::ClassificationAlias.classification_for_tree_with_name(f['tree_label'], f['aliases']) }

          (template_names.present? ? data.template_name.in?(template_names) : true) && (classification_ids.present? ? classification_ids.all? { |c| data.classifications.map(&:id).include?(c) } : true)
        end
      end
    end
  end
end
