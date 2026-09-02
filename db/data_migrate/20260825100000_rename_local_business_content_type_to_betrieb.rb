# frozen_string_literal: true

# [#48286] Renames the Inhaltstyp "LocalBusiness" to "Betrieb" — the schema.org type name means
# nothing to editors.
#
# datacycle-schema-tourism now declares the node as `$$Betrieb`, so its external_key is
# "Inhaltstypen > Ort > Betrieb". ConceptImporter only inserts and matches by external_key, so
# without this migration an existing database ends up with both nodes under Ort. The external_key
# therefore moves along with the label — on classification_aliases and on the primary
# classification, which is keyed the same way.
#
# Runs in every project (data migrations are gem-wide) but is inert where the concept does not
# exist. Because dc:update imports configs *before* the data migrations, the "Betrieb" node may
# already have been created by that import — then the old node is merged into it so content
# classified as LocalBusiness keeps its content type.
class RenameLocalBusinessContentTypeToBetrieb < ActiveRecord::Migration[8.0]
  OLD_EXTERNAL_KEY = 'Inhaltstypen > Ort > LocalBusiness'
  NEW_EXTERNAL_KEY = 'Inhaltstypen > Ort > Betrieb'
  NAME = 'Betrieb'
  # German only, exactly as importing `$$Betrieb` into a fresh database leaves it — the label is
  # deliberately not translated (#51239).
  NAME_I18N = { 'de' => NAME }.freeze

  def up
    old = concept(OLD_EXTERNAL_KEY)
    return say("no '#{OLD_EXTERNAL_KEY}' concept — nothing to rename") if old.nil?

    imported = concept(NEW_EXTERNAL_KEY)

    if imported.nil?
      rename(old)
      say("renamed '#{OLD_EXTERNAL_KEY}' to '#{NEW_EXTERNAL_KEY}'")
    else
      old.merge_with_children(imported)
      say("merged '#{OLD_EXTERNAL_KEY}' into the already imported '#{NEW_EXTERNAL_KEY}'")
    end
  end

  # Deliberately empty: on a database created after the rename, "Betrieb" is the imported name and
  # renaming it back would invent a LocalBusiness node that never existed there. A merged-away
  # node cannot be restored either.
  def down
  end

  private

  def rename(record)
    # Assigned wholesale rather than through Mobility's per-locale writer, which would merge and
    # leave a stale "LocalBusiness" behind in every other locale.
    record.name_i18n = NAME_I18N
    record.external_key = NEW_EXTERNAL_KEY
    record.save!

    # classifications keeps its own copy of both. The external_key is unique per external source,
    # so leaving it behind would make the import insert a second classification row; the name is
    # also synced by ClassificationAlias#update_primary_classification, but is set here so this
    # migration does not depend on that callback.
    record.primary_classification&.update!(name: NAME, external_key: NEW_EXTERNAL_KEY)
  end

  # System concepts carry their path as external_key; fall back to the path itself for databases
  # old enough to predate that.
  def concept(full_path)
    DataCycleCore::ClassificationAlias.find_by(external_key: full_path, external_source_id: nil) ||
      DataCycleCore::ClassificationAlias.by_full_paths(full_path).first
  end
end
