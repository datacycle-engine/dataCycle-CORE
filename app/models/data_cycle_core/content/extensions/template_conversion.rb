# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      # In-place type conversion of a content during import (e.g. POI -> Lift),
      # built on top of the STI casting in TemplateModels:
      #
      #   * can_become?(target)                - feasibility check
      #   * update_template!(target_template:) - perform the in-place conversion (gated + persisting)
      #   * preserved_property_names           - global + local attributes kept across any conversion
      #   * obsolete_property_names_for        - which attributes a conversion would drop
      #   * an after_update callback that removes obsolete attributes whenever template_name changed
      #
      # "in-place" refers to the RECORD: the same database row / GUID is kept (an UPDATE, not a
      # delete-and-reinsert), so no new record is created. It does NOT mean the same Ruby object - under
      # STI a loaded object's class cannot change, so update_template! returns a NEW instance re-cast to
      # the target template's subclass (via TemplateModels#becomes!); the original receiver is left as the
      # old subclass. Global/local attributes and anything the new template still defines are preserved
      # (the import re-maps the latter).
      #
      # Depends on TemplateModels (becomes!, template_name=/thing_template=, update_template_properties);
      # include TemplateModels first, then this concern.
      #
      # Feasibility rules:
      #   * Incoming links must remain valid in the target template (template_name + stored_filter constraints)
      #   * Preserved (global/local) outgoing links must be valid in the target template
      #   * All required target attributes must be fillable via import data, defaults, or surviving values
      module TemplateConversion
        extend ActiveSupport::Concern

        include PostConversionValidation

        included do
          after_update :cleanup_after_template_conversion, if: :template_name_previously_changed?
        end

        # Whether this content may be converted to the target template: are all existing relations valid
        # in the target type and all required target attributes fillable? (target: name or ThingTemplate)
        def can_become?(target, data: {})
          template_conversion_errors(target, data:).empty?
        end

        # The feasibility errors for converting to the target template (empty == can_become?).
        def template_conversion_errors(target, data: {})
          resolved_target = resolved_template_for(target)
          return ["target template not found: #{target}"] if resolved_target.nil?
          # embedded children are created/updated/destroyed by their embedding parent (no own import item,
          # external_key or history), so an in-place conversion here would be orphaned on the next parent
          # import - refuse it rather than corrupt the parent's embedded data.
          return ["embedded content '#{template_name}' cannot be converted: embedded children are managed by their parent and have no independent import path"] if embedded?

          invalid_incoming_relation_errors(resolved_target) +
            invalid_outgoing_relation_errors(resolved_target) +
            unfillable_required_property_errors(resolved_target, data.with_indifferent_access)
        end

        # Performs the in-place (same row/GUID) conversion and returns the converted record.
        #
        # This is the import-facing, GATED + PERSISTING wrapper around the becomes! cast primitive: it
        # checks feasibility (raising unless can_become?), then - in its own transaction - becomes! ->
        # save! (which fires the after_update cleanup that drops obsolete data) -> materializes the new
        # content-type classifications -> re-validates incoming and outgoing relations against the REAL
        # StoredFilter, now that the record actually carries the target type. Any failure rolls the conversion
        # back. Distinct from becomes!, the bare ungated unsaved cast - do not fold the gate/save into it.
        #
        # "in-place" is about the record (same row, same GUID, UPDATE not INSERT). The RETURNED object
        # is a NEW instance re-cast to the target subclass (the receiver's Ruby class cannot change under
        # STI), so it can be reloaded / queried without an STI SubclassNotFound; the receiver is stale.
        #
        # @raise [TemplateConversionError] if the conversion is infeasible or fails post-conversion
        #   validation - refuses to convert (rolling back) rather than corrupt data.
        def update_template!(target_template:, data: {})
          errors = template_conversion_errors(target_template, data:)
          raise build_template_conversion_error(target_template, errors) if errors.present?

          resolved_target = resolved_template_for(target_template)
          became = nil

          ActiveRecord::Base.transaction(requires_new: true) do
            became = becomes!(resolved_target.template_name)
            became.save!

            post_errors = became.send(:post_conversion_errors)
            raise build_template_conversion_error(target_template, post_errors) if post_errors.present?
          end

          became
        end

        # Property names preserved across any conversion (global + local attributes).
        def preserved_property_names
          (global_property_names + local_property_names).uniq
        end

        # Property names whose stored data is removed when converting to target_template: everything
        # except global/local (and internal) attributes is dropped, so the target's attributes are
        # re-mapped cleanly by the import. Required source attributes that the target still defines are
        # kept (re-mapped in place, avoiding a transient invalid/empty state and multi-locale loss).
        def obsolete_property_names_for(target_template)
          target = resolved_template_for(target_template)

          writable_property_names -
            global_property_names -
            local_property_names -
            internal_property_names -
            (required_property_names & Array.wrap(target&.property_names))
        end

        private

        # Resolves a conversion target to its ThingTemplate, accepting whatever shape the caller holds:
        #
        # - a ThingTemplate (returned as-is),
        # - a content/template Thing (the importer supplies Thing.new(template_name:) via load_template), or
        # - a template name as a String/Symbol.
        #
        # Returns nil when no such template exists (callers surface that as a feasibility error).
        def resolved_template_for(target)
          return target if target.is_a?(DataCycleCore::ThingTemplate)

          template_name = target.respond_to?(:template_name) ? target.template_name : target&.to_s
          DataCycleCore::ThingTemplate.find_by(template_name:)
        end

        def build_template_conversion_error(target_template, validation_errors)
          expected_template_name = target_template.respond_to?(:template_name) ? target_template.template_name : target_template&.to_s

          DataCycleCore::Error::Import::TemplateConversionError.new(
            template_name: template_name,
            expected_template_name:,
            external_key: external_key,
            validation_errors:
          )
        end

        # Removes obsolete attribute data after the template conversion (e.g. POI -> Lift), keeping the GUID,
        # global/local attributes, and anything the new template still defines. Uses the previous template's
        # definitions (the record is already on the new template here) and direct deletion, because
        # set_data_hash would slice obsolete attributes against the new template's schema.
        def cleanup_after_template_conversion
          return if history?

          previous_template_name = template_name_previously_was
          return if previous_template_name.blank?

          previous = DataCycleCore::Thing.new(template_name: previous_template_name)
          return if previous.template_missing?

          obsolete = previous.obsolete_property_names_for(thing_template)
          remove_obsolete_template_attribute_data(obsolete, previous) if obsolete.present?
        end

        def remove_obsolete_template_attribute_data(names, previous)
          obsolete_value_keys = []
          obsolete_translated_keys = []

          names.each do |name|
            if previous.linked_property_names.include?(name)
              content_content_a.where(relation_a: name).delete_all
            elsif previous.embedded_property_names.include?(name)
              destroy_embedded_children(name)
            elsif previous.classification_property_names.include?(name)
              classification_contents.where(relation: name).delete_all
            elsif previous.asset_property_names.include?(name)
              asset_contents.where(relation: name).destroy_all
            elsif previous.schedule_property_names.include?(name)
              DataCycleCore::Schedule.where(thing_id: id, relation: name).destroy_all
            elsif previous.timeseries_property_names.include?(name)
              DataCycleCore::Timeseries.where(thing_id: id, property: name).delete_all
            elsif previous.collection_property_names.include?(name)
              content_collection_links.where(relation: name).delete_all
            elsif previous.geo_property_names.include?(name)
              geometries.where(relation: name).destroy_all
            elsif previous.property_definitions.dig(name, 'storage_location') == 'translated_value'
              obsolete_translated_keys << name
            else
              obsolete_value_keys << name
            end
          end

          remove_obsolete_jsonb_data(obsolete_value_keys, obsolete_translated_keys)
        end

        def destroy_embedded_children(name)
          child_ids = content_content_a.where(relation_a: name).pluck(:content_b_id)
          content_content_a.where(relation_a: name).delete_all
          DataCycleCore::Thing.where(id: child_ids).find_each(&:destroy)
        end

        # value attributes live in the metadata jsonb column; translated_value attributes live in the
        # content jsonb of every translation (so obsolete translated values are cleared for all locales).
        # update_column is used to avoid re-triggering save callbacks from within after_update.
        def remove_obsolete_jsonb_data(value_keys, translated_keys)
          update_column(:metadata, (self[:metadata] || {}).except(*value_keys)) if value_keys.present?

          return if translated_keys.blank?

          translations.each do |translation|
            translation.update_column(:content, (translation.read_attribute(:content) || {}).except(*translated_keys))
          end
        end

        # Incoming links must remain valid in the target template. The relation is owned by the other
        # side and is NOT removed on conversion, so the target must still satisfy the type the relation
        # requires - whether expressed as an explicit template_name or as a classification stored_filter
        # (e.g. Inhaltstypen/Ort, a subtree that contains both POI and Lift but not Organisation).
        def invalid_incoming_relation_errors(target_template)
          return [] unless persisted?

          target_type_names = content_type_names(target_template)

          content_content_b.includes(:content_a).filter_map do |cc|
            parent = cc.content_a
            next if parent.nil?

            definition = parent.property_definitions[cc.relation_a]
            next if definition.blank? || incoming_relation_accepts_target?(definition, target_template, target_type_names)

            "incoming relation '#{cc.relation_a}' from '#{parent.template_name}' (#{parent.id}) does not allow target template '#{target_template.template_name}'"
          end
        end

        # Whether the target template is still an allowed target for an incoming relation. It must
        # satisfy *both* the relation's explicit template_name constraint and its classification
        # stored_filter constraint(s) when present.
        def incoming_relation_accepts_target?(definition, target_template, target_type_names)
          template_name_allows?(definition, target_template.template_name) &&
            classification_filters_satisfied?(definition, target_type_names)
        end

        # Outgoing links that survive the conversion (preserved global/local relations) must be valid
        # in the target template - each related content must satisfy the target relation's template_name
        # and classification stored_filter constraint(s).
        #
        # loads related contents directly (without applying the property's own stored_filter),
        # so the check can actually see contents that fall outside it.
        # an empty preserved relation carries no data, so a target that does not define it (or whose
        # constraints it would violate) cannot orphan anything - it must not block the conversion (#43079).
        def invalid_outgoing_relation_errors(target_template)
          return [] unless persisted?

          target_content = DataCycleCore::Thing.new(template_name: target_template.template_name)
          preserved_relation_names = preserved_property_names & (linked_property_names + embedded_property_names)

          preserved_relation_names.flat_map do |relation|
            related_contents = content_content_a.where(relation_a: relation).includes(:content_b).filter_map(&:content_b)
            next [] if related_contents.empty?

            definition = target_content.property_definitions[relation]
            next ["preserved relation '#{relation}' is not defined in target template '#{target_template.template_name}'"] if definition.blank?

            related_contents.filter_map do |related|
              next if template_name_allows?(definition, related.template_name) &&
                      outgoing_classification_filters_satisfied?(definition, content_type_names(related.thing_template))

              "outgoing relation '#{relation}' links '#{related.template_name}' (#{related.id}) which is not allowed in target template '#{target_template.template_name}'"
            end
          end
        end

        # Required attributes in the target template must be fillable via the import data or kept through the conversion.
        def unfillable_required_property_errors(target_template, data)
          target_content = DataCycleCore::Thing.new(template_name: target_template.template_name)
          surviving = property_names - obsolete_property_names_for(target_template)

          target_content.required_property_names.filter_map do |property|
            next if DataCycleCore::DataHashService.present?(data[property])
            next if target_content.default_value_property_names.include?(property)
            # value is not removed by the conversion and is already present on the content
            next if surviving.include?(property) && persisted? && DataCycleCore::DataHashService.present?(try(property))

            "required property '#{property}' of target template '#{target_template.template_name}' cannot be filled"
          end
        end

        def template_name_allows?(definition, template_name)
          allowed = Array.wrap(definition&.dig('template_name')).map(&:to_s)
          allowed.blank? || allowed.include?(template_name)
        end

        # Whether the candidate content-type names satisfy every classification stored_filter constraint
        # of the definition. The A→B implication ("if the source satisfies it, the candidate must too")
        # is correct for INCOMING relation checks: a constraint the source already satisfies must remain
        # satisfied after the conversion. Constraints on other classification trees never match a
        # content-type name, so !source_match short-circuits them without causing a false rejection.
        # Use outgoing_classification_filters_satisfied? for OUTGOING relation checks.
        def classification_filters_satisfied?(definition, candidate_type_names)
          source_type_names = content_type_names(thing_template)

          stored_filter_classification_constraints(definition).all? do |constraint|
            !classification_names_match?(source_type_names, constraint) ||
              classification_names_match?(candidate_type_names, constraint)
          end
        end

        # For outgoing relations the constraint applies directly to the related content — the converting
        # content's own classification is irrelevant. Stored_filter constraints on linked relations are
        # always about Inhaltstypen (content-type classification), so content_type_names gives sufficient
        # signal regardless of the converting content's own type.
        def outgoing_classification_filters_satisfied?(definition, candidate_type_names)
          stored_filter_classification_constraints(definition).all? do |constraint|
            classification_names_match?(candidate_type_names, constraint)
          end
        end

        # classification constraints (tree + aliases) from a relation's stored_filter, e.g.
        # Event#content_location -> { tree_label: 'Inhaltstypen', aliases: ['Ort'] }
        def stored_filter_classification_constraints(definition)
          Array.wrap(definition['stored_filter']).filter_map do |filter|
            config = filter['with_classification_aliases_and_treename']
            next if config.blank? || config['treeLabel'].blank? || config['aliases'].blank?

            { tree_label: config['treeLabel'], aliases: Array.wrap(config['aliases']) }
          end
        end

        def classification_names_match?(names, constraint)
          satisfying = DataCycleCore::ClassificationAlias
            .for_tree(constraint[:tree_label])
            .with_internal_name(constraint[:aliases])
            .with_descendants
            .pluck(:internal_name)
            .to_set
          names.any? { |name| satisfying.include?(name) }
        end

        # the content-type classification names a content of the given template would carry
        # (its data_type default, e.g. POI/Lift/Organisation, plus the template name as a fallback)
        def content_type_names(template)
          value = template&.schema&.dig('properties', 'data_type', 'default_value')
          [template&.template_name, value.is_a?(Hash) ? value['value'] : value].compact
        end
      end
    end
  end
end
