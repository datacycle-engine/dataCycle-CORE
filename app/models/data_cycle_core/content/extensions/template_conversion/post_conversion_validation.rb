# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module TemplateConversion
        # Validates that a just-converted record is actually sound as its new template: materializes the
        # new content-type classifications, then re-checks incoming and outgoing relations against the
        # real StoredFilter. Mixed into TemplateConversion.
        module PostConversionValidation
          private

          # [] when the conversion is sound, else the validation errors.
          def post_conversion_errors
            materialize_errors = materialize_template_default_errors
            return materialize_errors if materialize_errors.present?

            post_conversion_incoming_relation_errors + post_conversion_outgoing_relation_errors
          end

          # Materializes data_type/schema_types defaults synchronously (UpdateTemplateDefaultsJob's work),
          # so the StoredFilter re-check can join on the new content-type classifications.
          #
          # NB: Intentionally overlaps the async after_update :update_template_defaults callback (Content) -
          # the post-check needs the classifications NOW, not eventually; do not "dedupe" the two.
          def materialize_template_default_errors
            I18n.with_locale(first_available_locale) do
              data_hash = {}
              add_default_values(data_hash:, force: true, keys: DataCycleCore::UpdateTemplateDefaultsJob::TEMPLATE_DEFAULT_KEYS)
              next [] if set_data_hash(data_hash:, template_changed: true)

              errors.full_messages.presence || ["materializing template defaults failed for '#{template_name}'"]
            end
          end

          # Each surviving incoming link must still be admitted by its relation's stored_filter.
          def post_conversion_incoming_relation_errors
            return [] unless persisted?

            content_content_b.includes(:content_a).filter_map do |cc|
              parent = cc.content_a
              next if parent.nil?

              definition = parent.property_definitions[cc.relation_a]
              next if post_conversion_relation_filter_admits?(definition, id)

              "incoming relation '#{cc.relation_a}' from '#{parent.template_name}' (#{parent.id}) does not allow target template '#{template_name}'"
            end
          end

          # Each surviving preserved outgoing link must still be admitted by the target relation's stored_filter.
          # No materialization needed: the related contents are not being converted, so their classifications
          # are already current; the relation definition comes from the (target) template.
          def post_conversion_outgoing_relation_errors
            return [] unless persisted?

            preserved_relation_names = preserved_property_names & (linked_property_names + embedded_property_names)

            preserved_relation_names.flat_map do |relation|
              definition = property_definitions[relation]
              next [] if definition.blank?

              content_content_a.where(relation_a: relation).includes(:content_b).filter_map(&:content_b).filter_map do |related|
                next if post_conversion_relation_filter_admits?(definition, related.id)

                "outgoing relation '#{relation}' links '#{related.template_name}' (#{related.id}) which is not allowed in target template '#{template_name}'"
              end
            end
          end

          # Whether the relation's stored_filter admits content_id, via the real StoredFilter (every filter
          # type). No stored_filter => no classification constraint here (template_name is checked
          # pre-conversion). thing_ids_nested is locale-agnostic, matching linked-content loading.
          def post_conversion_relation_filter_admits?(definition, content_id)
            stored_filter = definition['stored_filter'] if definition.is_a?(::Hash)
            return true if stored_filter.blank?

            DataCycleCore::StoredFilter.new
              .parameters_from_hash(Array.wrap(stored_filter))
              .thing_ids_nested
              .include?(content_id)
          end
        end
      end
    end
  end
end
