# frozen_string_literal: true

class AddTriggersForCollections < ActiveRecord::Migration[6.1]
  def up
    remove_foreign_key :content_collection_links, :stored_filters
    remove_foreign_key :content_collection_links, :watch_lists
    remove_foreign_key :content_collection_link_histories, :stored_filters
    remove_foreign_key :content_collection_link_histories, :watch_lists

    execute <<-SQL.squish
      ALTER TABLE collections
      ADD COLUMN search_vector tsvector generated always AS (
          setweight(
            to_tsvector('simple', coalesce(name, '')),
            'A'
          ) || setweight(
            to_tsvector('simple', coalesce(slug, '')),
            'B'
          ) || setweight(
            to_tsvector('simple', coalesce(description_stripped, '')),
            'C'
          )
        ) stored;

      CREATE INDEX collections_search_vector_idx ON collections USING gin(search_vector);

      ALTER TABLE content_collection_links DROP COLUMN IF EXISTS stored_filter_id;

      ALTER TABLE content_collection_links DROP COLUMN IF EXISTS watch_list_id;

      ALTER TABLE content_collection_link_histories DROP COLUMN IF EXISTS stored_filter_id;

      ALTER TABLE content_collection_link_histories DROP COLUMN IF EXISTS watch_list_id;

      ALTER TABLE collection_shares
      ADD user_id uuid generated always AS (CASE
          WHEN shareable_type = 'DataCycleCore::User' THEN shareable_id
        END) stored;

      ALTER TABLE collection_shares
      ADD user_group_id uuid generated always AS (CASE
          WHEN shareable_type = 'DataCycleCore::UserGroup' THEN shareable_id
        END) stored;

      ALTER TABLE collection_shares
      ADD role_id uuid generated always AS (CASE
          WHEN shareable_type = 'DataCycleCore::Role' THEN shareable_id
        END) stored;

      DELETE FROM stored_filters sf
      WHERE NOT EXISTS (
          SELECT 1
          FROM users
          WHERE users.id = sf.user_id
        );

      DELETE FROM watch_lists wl
      WHERE NOT EXISTS (
          SELECT 1
          FROM users
          WHERE users.id = wl.user_id
        );

      INSERT INTO collections(
          id,
          TYPE,
          name,
          slug,
          description,
          user_id,
          full_path,
          full_path_names,
          my_selection,
          manual_order,
          api,
          created_at,
          updated_at
        )
      SELECT wl.id,
        'DataCycleCore::WatchList',
        wl.name,
        cc.slug,
        cc.description,
        wl.user_id,
        wl.full_path,
        wl.full_path_names,
        wl.my_selection,
        wl.manual_order,
        wl.api,
        wl.created_at,
        wl.updated_at
      FROM watch_lists wl
        LEFT OUTER JOIN collection_configurations cc ON cc.watch_list_id = wl.id;

      INSERT INTO collections(
          id,
          TYPE,
          name,
          slug,
          description,
          user_id,
          api,
          language,
          created_at,
          updated_at,
          parameters,
          sort_parameters,
          linked_stored_filter_id
        )
      SELECT sf.id,
        'DataCycleCore::StoredFilter',
        sf.name,
        cc.slug,
        cc.description,
        sf.user_id,
        sf.api,
        sf.language,
        sf.created_at,
        sf.updated_at,
        sf.parameters,
        sf.sort_parameters,
        sf.linked_stored_filter_id
      FROM stored_filters sf
        LEFT OUTER JOIN collection_configurations cc ON cc.stored_filter_id = sf.id;

      INSERT INTO collection_concept_scheme_links(concept_scheme_id, collection_id)
      SELECT ctl::UUID,
        sf.id
      FROM stored_filters sf,
        unnest(sf.classification_tree_labels) ctl
      WHERE ctl IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM concept_schemes
          WHERE concept_schemes.id = ctl::UUID
        );

      INSERT INTO collection_shares(collection_id, shareable_id, shareable_type)
      SELECT wls.watch_list_id,
        wls.shareable_id,
        wls.shareable_type
      FROM watch_list_shares wls
      WHERE EXISTS (
        SELECT 1
        FROM watch_lists
        WHERE watch_lists.id = wls.watch_list_id
      );

      INSERT INTO collection_shares(shareable_id, shareable_type, collection_id)
      SELECT api_user::UUID,
        'DataCycleCore::User',
        sf.id
      FROM stored_filters sf,
        unnest(sf.api_users) api_user
      WHERE api_user IS NOT NULL
        AND api_user != ''
        AND EXISTS (
          SELECT 1
          FROM users
          WHERE users.id = api_user::UUID
        );

      INSERT INTO collection_shares(shareable_id, shareable_type, collection_id)
      SELECT roles.id,
        'DataCycleCore::Role',
        sf.id
      FROM stored_filters sf,
        roles
      WHERE sf.system = TRUE;

      CREATE OR REPLACE FUNCTION generate_unique_collection_slug(old_slug VARCHAR, OUT new_slug VARCHAR) LANGUAGE PLPGSQL AS $$ BEGIN WITH input AS (
          SELECT old_slug::VARCHAR AS slug,
            regexp_replace(old_slug, '-\\d*$', '')::VARCHAR || '-' AS base_slug
        )
      SELECT i.slug
      FROM input i
        LEFT JOIN collections a USING (slug)
      WHERE a.slug IS NULL
      UNION ALL
      (
        SELECT i.base_slug || COALESCE(
            right(a.slug, length(i.base_slug) * -1)::int + 1,
            1
          )
        FROM input i
          LEFT JOIN collections a ON a.slug LIKE (i.base_slug || '%')
          AND right(a.slug, length(i.base_slug) * -1) ~ '^\\d+$'
        ORDER BY right(a.slug, length(i.base_slug) * -1)::int DESC
      )
      LIMIT 1 INTO new_slug;

      END;

      $$;

      CREATE TRIGGER generate_collection_slug_trigger BEFORE
      INSERT ON collections FOR EACH ROW
        WHEN (NEW.slug IS NOT NULL) EXECUTE FUNCTION generate_collection_slug_trigger ();

      CREATE TRIGGER update_collection_slug_trigger BEFORE
      UPDATE OF slug ON collections FOR EACH ROW
        WHEN (NEW.slug IS NOT NULL
        AND
          OLD.slug IS DISTINCT
          FROM NEW.slug
        ) EXECUTE FUNCTION generate_collection_slug_trigger ();

      CREATE OR REPLACE FUNCTION generate_my_selection_watch_list() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN IF EXISTS (
          SELECT
          FROM roles
          WHERE roles.id = NEW.role_id
            AND roles.rank <> 0
        ) THEN
      INSERT INTO collections (
          name,
          TYPE,
          user_id,
          created_at,
          updated_at,
          full_path,
          full_path_names,
          my_selection
        )
      SELECT 'Meine Auswahl',
        'DataCycleCore::WatchList',
        users.id,
        NOW(),
        NOW(),
        'Meine Auswahl',
        ARRAY []::varchar [],
        TRUE
      FROM users
        INNER JOIN roles ON roles.id = users.role_id
      WHERE users.id = NEW.id
        AND roles.rank <> 0
        AND NOT EXISTS (
          SELECT 1
          FROM collections
          WHERE collections.my_selection
            AND collections.user_id = users.id
        );

      ELSE
      DELETE FROM collections
      WHERE collections.user_id = NEW.id
        AND collections.my_selection;

      END IF;

      RETURN NEW;

      END;

      $$;
    SQL

    add_foreign_key :content_collection_links, :collections, on_delete: :cascade
    add_foreign_key :content_collection_link_histories, :collections, on_delete: :cascade

    remove_column :content_collection_links, :collection_type, :string
    remove_column :content_collection_link_histories, :collection_type, :string

    add_index :content_collection_links, [:thing_id, :relation, :collection_id], unique: true, name: 'ccl_unique_index'
    add_foreign_key :collection_shares, :users, on_delete: :cascade
    add_foreign_key :collection_shares, :user_groups, on_delete: :cascade
    add_foreign_key :collection_shares, :roles, on_delete: :cascade
    add_foreign_key :watch_list_data_hashes, :collections, column: :watch_list_id, on_delete: :cascade, on_update: :cascade
  end

  def down
    remove_foreign_key :content_collection_links, :collections
    remove_foreign_key :content_collection_link_histories, :collections

    add_column :content_collection_links, :collection_type, :string
    add_column :content_collection_link_histories, :collection_type, :string

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION generate_unique_collection_slug(old_slug VARCHAR, OUT new_slug VARCHAR) LANGUAGE PLPGSQL AS $$ BEGIN WITH input AS (
          SELECT old_slug::VARCHAR AS slug,
          regexp_replace(old_slug, '-\\d*$', '')::VARCHAR || '-' AS base_slug
        )
      SELECT i.slug
      FROM input i
        LEFT JOIN collection_configurations a USING (slug)
      WHERE a.slug IS NULL
      UNION ALL
      (
        SELECT i.base_slug || COALESCE(
            right(a.slug, length(i.base_slug) * -1)::int + 1,
            1
          )
        FROM input i
          LEFT JOIN collection_configurations a ON a.slug LIKE (i.base_slug || '%')
          AND right(a.slug, length(i.base_slug) * -1) ~ '^\\d+$'
        ORDER BY right(a.slug, length(i.base_slug) * -1)::int DESC
      )
      LIMIT 1 INTO new_slug;

      END;

      $$;

      ALTER TABLE content_collection_links
      ADD COLUMN stored_filter_id uuid generated always AS (CASE
          WHEN collection_type = 'DataCycleCore::StoredFilter' THEN collection_id
        END) stored;

      ALTER TABLE content_collection_links
      ADD COLUMN watch_list_id uuid generated always AS (CASE
          WHEN collection_type = 'DataCycleCore::WatchList' THEN collection_id
        END) stored;

      ALTER TABLE content_collection_link_histories
      ADD COLUMN stored_filter_id uuid generated always AS (
          CASE
            WHEN collection_type = 'DataCycleCore::StoredFilter' THEN collection_id
          END
        ) stored;

      ALTER TABLE content_collection_link_histories
      ADD COLUMN watch_list_id uuid generated always AS (
          CASE
            WHEN collection_type = 'DataCycleCore::WatchList' THEN collection_id
          END
        ) stored;

      CREATE OR REPLACE FUNCTION generate_my_selection_watch_list() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN IF EXISTS (
          SELECT
          FROM roles
          WHERE roles.id = NEW.role_id
            AND roles.rank <> 0
        ) THEN
        INSERT INTO watch_lists (
            name,
            user_id,
            created_at,
            updated_at,
            full_path,
            full_path_names,
            my_selection
          )
        SELECT 'Meine Auswahl',
          users.id,
          NOW(),
          NOW(),
          'Meine Auswahl',
          ARRAY []::varchar [],
          TRUE
        FROM users
          INNER JOIN roles ON roles.id = users.role_id
        WHERE users.id = NEW.id
          AND roles.rank <> 0
          AND NOT EXISTS (
            SELECT
            FROM watch_lists
            WHERE watch_lists.my_selection
              AND watch_lists.user_id = users.id
          );

        ELSE
        DELETE FROM watch_lists
        WHERE watch_lists.user_id = NEW.id
          AND watch_lists.my_selection;

        END IF;

        RETURN NEW;

        END;

        $$;
    SQL

    remove_foreign_key :watch_list_data_hashes, :collections, column: :watch_list_id

    add_foreign_key :content_collection_links, :stored_filters, column: :stored_filter_id, on_delete: :cascade
    add_foreign_key :content_collection_links, :watch_lists, column: :watch_list_id, on_delete: :cascade
    add_foreign_key :content_collection_link_histories, :stored_filters, column: :stored_filter_id, on_delete: :cascade
    add_foreign_key :content_collection_link_histories, :watch_lists, column: :watch_list_id, on_delete: :cascade
  end
end
