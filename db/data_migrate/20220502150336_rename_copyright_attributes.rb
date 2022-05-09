# frozen_string_literal: true

class RenameCopyrightAttributes < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    key_old = 'license'
    key_new = 'copyright_notice_override'
    execute <<-SQL.squish
      UPDATE things
      SET metadata = (metadata - '#{key_old}') || jsonb_build_object('#{key_new}', metadata #> '{"#{key_old}"}' )
      WHERE metadata #> '{"#{key_old}"}' IS NOT NULL
    SQL
  end

  def down
    key_old = 'copyright_notice_override'
    key_new = 'license'
    execute <<-SQL.squish
      UPDATE things
      SET metadata = (metadata - '#{key_old}') || jsonb_build_object('#{key_new}', metadata #> '{"#{key_old}"}' )
      WHERE metadata #> '{"#{key_old}"}' IS NOT NULL
    SQL
  end
end
