# frozen_string_literal: true

# [#47270] Ski resorts showed up in the "Unterkünfte" filter because schema.org files SkiResort
# under LodgingBusiness. The Inhaltstypen leafs therefore now map to the template specific dcls:
# leafs (classification_mappings.yml of the schema gems) instead of the schema.org parent node.
#
# DataCycleCore::MasterData::Concepts::ConceptImporter#insert_concept_mappings only ever inserts
# (insert_all) and never removes a mapping that disappeared from a YAML. Without this cleanup the
# old parent mapping would stay next to the new one and the filter would still match everything
# below LodgingBusiness.
#
# Only mappings this change superseded are removed: a node mapping whose Inhaltstyp the YAMLs now
# map to a dcls: leaf directly below that node. Hand-made mappings (classifications_controller
# lets editors map Inhaltstypen) are concept_links like the imported ones and carry no marker, so
# "absent from the YAMLs" would delete them too - irreversibly, in every project.
#
# Removal goes through ClassificationMappingJob - the same path the classification UI takes when a
# mapping is deselected. The job deletes the related concept_links and hands the affected concepts
# to Concept#mapped_concepts_changed, which rebuilds the derived paths and contents.
class RemoveStaleSchemaTypeMappings < ActiveRecord::Migration[8.0]
  SOURCE_TREE = 'Inhaltstypen'
  TARGET_TREE = 'SchemaTypes'

  def up
    stale = stale_target_ids_by_source
    return say('no stale mappings found') if stale.blank?

    repair_contents_losing_their_type(stale)

    say("removing #{stale.values.sum(&:size)} stale #{SOURCE_TREE} -> #{TARGET_TREE} mappings on #{stale.size} concepts")

    stale.each do |source_id, target_ids|
      DataCycleCore::ClassificationMappingJob.perform_later(source_id, [], target_ids)
    end
  end

  # Irreversible: the concept importer restores the state described by the YAMLs.
  def down
  end

  private

  # BackfillSchemaTypeClassifications (20260806110000) moves a content's schema_types onto its
  # dcls: leaf, but only where there is a schema_types row to move. Content predating the property
  # carries the schema.org node as a universal_classification instead (an Organization on
  # SchemaTypes > Organization) and matches its Inhaltstyp through that alone, so repointing the
  # mapping below would drop it out of its own content type filter.
  #
  # Those contents get the schema_types default their template defines - what
  # dc:update_data:add_defaults[false,false,schema_types] writes, restricted to the contents that
  # need it. The domain path is affordable because the set based backfill ran first and left only
  # the contents it could not reach.
  #
  # The universal_classification stays: it is editor and import data, and once the mapping points
  # at the dcls: leaf it no longer drives the filter.
  def repair_contents_losing_their_type(stale)
    thing_ids = contents_losing_their_type(stale)
    return if thing_ids.blank?

    say("adding the missing schema_types classification to #{thing_ids.size} contents")
    add_schema_type_defaults(thing_ids)

    remaining = contents_losing_their_type(stale)
    return if remaining.blank?

    templates = DataCycleCore::Thing.where(id: remaining).distinct.pluck(:template_name).sort

    raise ActiveRecord::MigrationError, <<~MSG.squish
      #{remaining.size} contents (#{templates.join(', ')}) match their #{SOURCE_TREE} only through
      a schema.org parent concept, and the schema_types their template defines resolve to no
      concept that #{SOURCE_TREE} still maps to - removing the mapping would drop them out of the
      filter. Reclassify them or extend the template's schema_ancestors, then re-run.
    MSG
  end

  # prevent_webhooks: the repair writes the classification the content should have carried all
  # along, so there is no editorial change for a subscriber to hear about.
  def add_schema_type_defaults(thing_ids)
    DataCycleCore::Thing.where(id: thing_ids).find_each do |content|
      content.prevent_webhooks = true

      I18n.with_locale(content.first_available_locale) do
        data_hash = {}
        content.add_default_values(data_hash:, force: true, keys: ['schema_types'])
        content.set_data_hash(data_hash:)
      end
    end
  end

  # A content survives the removal when it is classified on one of the concepts its Inhaltstyp
  # still maps to - the schema.org node it also sits on stops mattering. Counting every content on
  # the node instead would also block on universal_classifications, which no backfill clears.
  def contents_losing_their_type(stale)
    select_values(<<~SQL.squish)
      SELECT DISTINCT ccc.thing_id
      FROM (VALUES #{removed_mapping_values(stale)}) AS removed (concept_id, kept_ids)
        INNER JOIN collected_concept_contents ccc
          ON ccc.concept_id = removed.concept_id AND ccc.link_type = 'direct'
      WHERE NOT EXISTS (
        SELECT 1
        FROM collected_concept_contents kept
        WHERE kept.thing_id = ccc.thing_id
          AND kept.link_type = 'direct'
          AND kept.concept_id = ANY (removed.kept_ids)
      )
    SQL
  end

  # One row per removed mapping: the schema.org node, and the concepts its Inhaltstyp keeps.
  def removed_mapping_values(stale)
    kept_ids_by_source = desired_pairs.group_by(&:first).transform_values { |pairs| pairs.map(&:last).uniq }

    stale.flat_map { |source_id, node_ids|
      kept_ids = kept_ids_by_source.fetch(source_id).map { |id| connection.quote(id) }.join(', ')

      node_ids.map { |node_id| "(#{connection.quote(node_id)}::uuid, ARRAY[#{kept_ids}]::uuid[])" }
    }.join(', ')
  end

  def stale_target_ids_by_source
    node_pairs_with_leaf
      .select { |source_id, _node_id, leaf_id| desired_pairs.include?([source_id, leaf_id]) }
      .reject { |source_id, node_id, _leaf_id| desired_pairs.include?([source_id, node_id]) }
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:second).uniq }
  end

  # Desired state from every loaded classification_mappings.yml, resolved to
  # [source_concept_id, target_concept_id] - the same pairing the importer inserts.
  def desired_pairs
    @desired_pairs ||= begin
      mappings = DataCycleCore::MasterData::Concepts::ConceptImporter.new(import_concepts: false).concept_mappings.to_h
      concepts = concept_ids_by_full_path(mappings.keys + mappings.values.flatten)

      mappings.flat_map { |source_path, target_paths|
        sources = concepts[source_path]
        next [] if sources.blank?

        Array.wrap(target_paths).flat_map do |target_path|
          targets = concepts[target_path]
          next [] if targets.blank?

          sources.product(targets)
        end
      }.to_set
    end
  end

  # group_by instead of index_by: a full_path can occur more than once.
  def concept_ids_by_full_path(full_paths)
    DataCycleCore::Concept
      .by_full_paths(full_paths.uniq)
      .group_by(&:full_path)
      .transform_values { |concepts| concepts.map(&:id) }
  end

  # Every existing Inhaltstypen -> SchemaTypes mapping onto a schema.org node, once per dcls: leaf
  # directly below that node: [source_concept_id, node_concept_id, leaf_concept_id].
  def node_pairs_with_leaf
    select_rows(<<~SQL.squish)
      SELECT cl.parent_id, cl.child_id, leaf_paths.id
      FROM concept_links cl
        INNER JOIN concept_paths source_paths ON source_paths.id = cl.parent_id
        INNER JOIN concept_paths node_paths ON node_paths.id = cl.child_id
        INNER JOIN concept_paths leaf_paths
          ON leaf_paths.full_path_names[2:array_length(leaf_paths.full_path_names, 1)] = node_paths.full_path_names
          AND leaf_paths.full_path_names[1] LIKE 'dcls:%'
      WHERE cl.link_type = #{connection.quote(DataCycleCore::ConceptLink::LINK_TYPE_RELATED)}
        AND node_paths.full_path_names[1] NOT LIKE 'dcls:%'
        AND source_paths.full_path_names[array_length(source_paths.full_path_names, 1)] = #{connection.quote(SOURCE_TREE)}
        AND node_paths.full_path_names[array_length(node_paths.full_path_names, 1)] = #{connection.quote(TARGET_TREE)}
    SQL
  end
end
