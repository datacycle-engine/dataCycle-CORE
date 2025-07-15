# frozen_string_literal: true

class CreateHistoricThingHistoryLinks < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      with recursive build_history_links as(
          select things.id,
                 substring(things.version_name from '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}')::uuid as merged_thing_uuid
          from things where version_name ilike '%zusammengeführt mit%'
                      union
                      select thing_histories.thing_id,
                             substring(thing_histories.version_name from '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}')::uuid as merged_thing_uuid
                      from thing_histories
          where version_name ilike '%zusammengeführt mit%'
      ), recursive_lookup as (
          select build_history_links.id, merged_thing_uuid from build_history_links
                                              where exists(
                                                  select 1 from things where things.id = build_history_links.id
                                              )
          union
          select recursive_lookup.id, build_history_links.merged_thing_uuid from build_history_links
          join recursive_lookup on recursive_lookup.merged_thing_uuid = build_history_links.id
      ), to_insert as (
          select recursive_lookup.id as thing_id, thing_histories.id as thing_history_id  from recursive_lookup join thing_histories on thing_histories.thing_id = recursive_lookup.merged_thing_uuid and thing_histories.deleted_at is not null
      )

      insert into thing_history_links (thing_id, thing_history_id, created_at, updated_at)
      select to_insert.thing_id, to_insert.thing_history_id, now(), now() from to_insert
      on conflict do nothing;
    SQL
  end

  def down
  end
end
