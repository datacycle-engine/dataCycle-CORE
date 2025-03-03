# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module ConceptTransformations
        def mapped_concepts_to_property(concept_scheme:, current_user: nil)
          return if concept_scheme.nil?

          attribute_names = attribute_names_for_concept_scheme(concept_scheme)
          classification_ids = classification_ids_for_concept_scheme(concept_scheme)

          return if classification_ids.blank?

          data_hash = attribute_names.index_with { |an| (Array.wrap(try(an)&.pluck(:id)) + classification_ids).uniq }

          set_data_hash(
            data_hash:,
            version_name: I18n.t('concept_scheme_link.version_name', data: concept_scheme.name, locale: current_user&.ui_locale || I18n.default_locale),
            current_user:
          )
        end

        def remove_concepts_by_scheme(concept_scheme:, current_user: nil)
          return if concept_scheme.nil?

          groups = grouped_ccc_by_concept_scheme(concept_scheme)

          return if groups.blank?

          data_hash = groups.to_h do |relation, classification_ids|
            [relation, Array.wrap(try(relation)&.pluck(:id)) - classification_ids]
          end

          set_data_hash(
            data_hash:,
            version_name: I18n.t('concept_scheme_unlink.version_name', data: concept_scheme.name, locale: current_user&.ui_locale || I18n.default_locale),
            current_user:
          )
        end

        private

        def grouped_ccc_by_concept_scheme(concept_scheme)
          collected_classification_contents
            .where(classification_tree_label_id: concept_scheme.id, link_type: 'direct')
            .includes(:concept)
            .group_by(&:relation)
            .transform_values { |cccs| cccs.flat_map(&:concept).map(&:classification_id) }
        end

        def classification_ids_for_concept_scheme(concept_scheme)
          collected_classification_contents
            .where(link_type: 'related', classification_tree_label_id: concept_scheme.id)
            .includes(:concept)
            .filter_map { |ccc| ccc.concept&.classification_id }
            .uniq
        end

        def attribute_names_for_concept_scheme(concept_scheme)
          attribute_names = classification_properties.filter { |_, v| v['tree_label'] == concept_scheme.name }.keys
          attribute_names = ['universal_classifications'] if attribute_names.blank? && respond_to?(:universal_classifications)
          raise DataCycleCore::Errors::NoValidClassificationAttributeError, "No matching classification properties found for concept_scheme #{concept_scheme.name}" if attribute_names.blank?

          attribute_names
        end
      end
    end
  end
end
