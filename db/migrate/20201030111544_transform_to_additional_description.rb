# frozen_string_literal: true

class TransformToAdditionalDescription < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      UPDATE content_contents
      SET relation_a = 'additional_information'
      FROM things
      WHERE content_contents.relation_a = 'subject_of'
        AND content_contents.content_a_id = things.id
        AND things.template_name = 'Service';
    SQL
  end

  def down
  end
end
