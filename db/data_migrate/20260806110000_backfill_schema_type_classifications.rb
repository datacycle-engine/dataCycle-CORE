# frozen_string_literal: true

# [#47270] First half of the dcls: move, see RemoveStaleSchemaTypeMappings for the second. Every
# template now gets its own leaf in the SchemaTypes tree (e.g. SchemaTypes > Place > LocalBusiness
# > LodgingBusiness > dcls:LodgingBusiness), but existing content only follows on its next save.
# Until then it hangs on the shared schema.org node - and drops out of its own content type filter
# as soon as the Inhaltstypen mapping is repointed to the leaf.
#
# Set based instead of add_default_values/set_data_hash: the domain path would load and rewrite
# hundreds of thousands of contents one by one although only concept_id changes.
#
# The rows to move are collected into a temp table because the rebuild below reads the same set
# back; it is ANALYZEd so the UPDATE that joins it is planned on measured row counts.
#
# The AFTER UPDATE row trigger on concept_id is disabled around that UPDATE and
# collected_concept_contents rebuilt explicitly instead: the trigger hands a single thing to a
# function that accepts an array, so it pays the rebuild once per updated row, ten times the per
# thing cost of the batched call - 3m12s covers all 556_299 things at once. Which trigger and
# function that is follows Feature::TransitiveClassificationPath, and the database agrees with the
# flag by the time this runs: RebuildCccWithoutTransitive (20250424140212) and
# RebuildCccAfterNewLogic (20260116090937) have each called .update_triggers for their half of it.
#
# The target is resolved by path, not hardcoded per template: a content's leaf is its current path
# plus "dcls:<template_name>", the same rule as ThingTemplate#schema_types. Where no such leaf
# exists the row stays and the follow-up migration refuses to run.
#
# Runs in every project (data migrations are gem-wide) and is inert where nothing is left to move.
class BackfillSchemaTypeClassifications < ActiveRecord::Migration[8.0]
  def up
    execute('SET LOCAL statement_timeout = 0;')
    collect_moves

    moved = select_value('SELECT count(*) FROM schema_type_moves').to_i
    return say('no schema_types left on a shared SchemaTypes node') if moved.zero?

    say("moving #{moved} schema_types concepts onto their dcls: leaf")
    without_ccc_row_trigger { apply_moves }
    rebuild_collected_concept_contents
  end

  # Irreversible: dc:update_data:add_defaults with schema_types restores the intended state.
  def down
  end

  private

  def collect_moves
    execute(<<~SQL.squish)
      CREATE TEMPORARY TABLE schema_type_moves ON COMMIT DROP AS
      SELECT cc.id, cc.content_data_id AS thing_id, new_p.id AS concept_id
      FROM concept_contents cc
        INNER JOIN concept_paths old_p ON old_p.id = cc.concept_id
        INNER JOIN things t ON t.id = cc.content_data_id
        INNER JOIN concept_paths new_p
          ON new_p.full_path_names = ARRAY['dcls:' || t.template_name]::varchar[] || old_p.full_path_names
      WHERE cc.relation = 'schema_types'
        AND old_p.full_path_names[array_length(old_p.full_path_names, 1)] = 'SchemaTypes'
        AND NOT EXISTS (
          SELECT 1
          FROM concept_contents dup
          WHERE dup.content_data_id = cc.content_data_id
            AND dup.concept_id = new_p.id
            AND dup.relation = cc.relation
        )
    SQL

    execute('ANALYZE schema_type_moves')
  end

  # A full_path can occur more than once, so a content can collect two rows in schema_type_moves;
  # UPDATE ... FROM then applies one of them, the same arbitrary pick the single statement made.
  def apply_moves
    execute(<<~SQL.squish)
      UPDATE concept_contents cc
      SET concept_id = m.concept_id
      FROM schema_type_moves m
      WHERE m.id = cc.id
    SQL
  end

  def rebuild_collected_concept_contents
    execute("SELECT #{ccc_rebuild_call} FROM schema_type_moves")
  end

  def without_ccc_row_trigger
    execute("ALTER TABLE concept_contents DISABLE TRIGGER #{ccc_update_trigger}")
    yield
    execute("ALTER TABLE concept_contents ENABLE TRIGGER #{ccc_update_trigger}")
  end

  def ccc_update_trigger
    return 'update_ccc_relations_transitive_trigger' if transitive_paths?

    'update_collected_concept_content_relations_trigger_1'
  end

  def ccc_rebuild_call
    return 'generate_collected_concept_content_relations_transitive(array_agg(DISTINCT thing_id))' if transitive_paths?

    'generate_collected_concept_content_relations(array_agg(DISTINCT thing_id))'
  end

  def transitive_paths?
    DataCycleCore::Feature::TransitiveClassificationPath.enabled?
  end
end
