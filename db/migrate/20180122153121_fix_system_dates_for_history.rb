# frozen_string_literal: true

class FixSystemDatesForHistory < ActiveRecord::Migration[5.0]
  def up
    @connection = ActiveRecord::Base.connection
    ['creative_works', 'events', 'persons', 'places'].each do |table_name|
      content = table_name.singularize
      next unless @connection.table_exists?(table_name)

      query = <<-EOS
        WITH t AS (
          SELECT
            #{content}_histories.id AS id,
            (upper(#{content}_history_translations.history_valid) at time zone 'UTC')::timestamp without time zone AS new_created_at
          FROM #{content}_histories
          INNER JOIN #{content}_history_translations
            ON #{content}_history_translations.#{content}_history_id = #{content}_histories.id
          AND upper(#{content}_history_translations.history_valid) IS NOT NULL
        )
        UPDATE #{content}_histories
        SET updated_at = t.new_created_at, created_at = t.new_created_at
        FROM t
        WHERE #{content}_histories.id = t.id;
      EOS

      @connection.exec_query(query)
    end
  end

  def down
    # irreversible
  end
end
