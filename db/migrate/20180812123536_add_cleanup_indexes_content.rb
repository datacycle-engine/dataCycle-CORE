# frozen_string_literal: true

class AddCleanupIndexesContent < ActiveRecord::Migration[5.1]
  def up
    remove_index :creative_works, name: 'index_creative_works_on_external_key' if index_exists?(:creative_works, :external_key, **{name: 'index_creative_works_on_external_key'})
    add_index :creative_works, [:external_source_id, :external_key], name: 'index_cw_on_external_source_id_and_external_key' unless index_exists?(:creative_works, [:external_source_id, :external_key], **{name: 'index_cw_on_external_source_id_and_external_key'})
    remove_index :creative_works, name: 'index_creative_works_on_metadata_validation_name' if index_exists?(:creative_works, :external_key, **{name: 'index_creative_works_on_metadata_validation_name'})

    add_index :event_translations, [:event_id, :locale], unique: true, name: 'by_et_ei_locale' unless index_exists?(:event_translations, [:event_id, :locale], **{unique: true, name: 'by_et_ei_locale'})
    add_index :events, :id, unique: true unless index_exists?(:events, :id, **{unique: true})
    add_index :events, :external_source_id unless index_exists?(:events, :external_source_id)
    add_index :events, [:external_source_id, :external_key], name: 'index_e_on_external_source_id_and_external_key' unless index_exists?(:events, [:external_source_id, :external_key], **{name: 'index_e_on_external_source_id_and_external_key'})
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_events_on_content_type ON events ((schema ->> 'content_type'))
    SQL

    add_index :organization_translations, [:organization_id, :locale], unique: true, name: 'by_ot_ei_locale' unless index_exists?(:organization_translations, [:organization_id, :locale], **{unique: true, name: 'by_ot_ei_locale'})
    add_index :organizations, :id, unique: true unless index_exists?(:organizations, :id, **{unique: true})
    add_index :organizations, :external_source_id unless index_exists?(:organizations, :external_source_id)
    add_index :organizations, [:external_source_id, :external_key], name: 'index_o_on_external_source_id_and_external_key' unless index_exists?(:organizations, [:external_source_id, :external_key], **{name: 'index_o_on_external_source_id_and_external_key'})
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_organizations_on_content_type ON organizations ((schema ->> 'content_type'))
    SQL

    add_index :person_translations, [:person_id, :locale], unique: true, name: 'by_persont_pi_locale' unless index_exists?(:person_translations, [:person_id, :locale], **{unique: true, name: 'by_persont_pi_locale'})
    add_index :persons, :id, unique: true unless index_exists?(:persons, :id, **{unique: true})
    add_index :persons, :external_source_id unless index_exists?(:persons, :external_source_id)
    add_index :persons, [:external_source_id, :external_key], name: 'index_pers_on_external_source_id_and_external_key' unless index_exists?(:persons, [:external_source_id, :external_key], **{name: 'index_pers_on_external_source_id_and_external_key'})
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_persons_on_content_type ON persons ((schema ->> 'content_type'))
    SQL
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_places_on_content_type ON places ((schema ->> 'content_type'))
    SQL
  end

  def down
    remove_index :places, name: 'index_places_on_content_type'

    remove_index :persons, name: 'index_persons_on_content_type'
    remove_index :persons, name: 'index_pers_on_external_source_id_and_external_key'
    remove_index :persons, :external_source_id
    remove_index :persons, :id
    remove_index :person_translations, name: 'by_persont_pi_locale'

    remove_index :organizations, name: 'index_organizations_on_content_type'
    remove_index :organizations, name: 'index_o_on_external_source_id_and_external_key'
    remove_index :organizations, :external_source_id
    remove_index :organizations, :id
    remove_index :organization_translations, name: 'by_ot_ei_locale'

    remove_index :events, name: 'index_events_on_content_type'
    remove_index :events, name: 'index_e_on_external_source_id_and_external_key'
    remove_index :events, :external_source_id
    remove_index :events, :id
    remove_index :event_translations, name: 'by_et_ei_locale'

    add_index :creative_works, "(metadata #>> '{ validation, name }')", name: 'index_creative_works_on_metadata_validation_name'
    remove_index :creative_works, name: 'index_cw_on_external_source_id_and_external_key'
    execute <<-SQL
      CREATE INDEX index_creative_works_on_external_key ON creative_works ((metadata ->> 'external_key'), external_source_id)
    SQL
  end
end
