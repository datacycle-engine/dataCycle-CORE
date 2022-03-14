# frozen_string_literal: true

class RenameContactInfoNameToContactInfoContactName < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    key_old = 'name'
    key_new = 'contact_name'
    execute <<-SQL.squish
      UPDATE thing_translations
      SET content = (content - 'contact_info') || jsonb_build_object('contact_info', ((content -> 'contact_info')::jsonb - '#{key_old}') || jsonb_build_object('#{key_new}', content #> '{"contact_info", "#{key_old}"}') )
      WHERE content #> '{"contact_info", "#{key_old}"}' IS NOT NULL
    SQL
  end

  def down
    key_old = 'contact_name'
    key_new = 'name'
    execute <<-SQL.squish
      UPDATE thing_translations
      SET content = (content - 'contact_info') || jsonb_build_object('contact_info', ((content -> 'contact_info')::jsonb - '#{key_old}') || jsonb_build_object('#{key_new}', content #> '{"contact_info", "#{key_old}"}') )
      WHERE content #> '{"contact_info", "#{key_old}"}' IS NOT NULL
    SQL
  end
end
