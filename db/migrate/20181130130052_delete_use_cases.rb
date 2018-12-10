# frozen_string_literal: true

class DeleteUseCases < ActiveRecord::Migration[5.1]
  def up
    drop_table :use_cases, if_exists: true
  end

  def down
    create_table :use_cases, id: :uuid do |t|
      t.uuid :user_id
      t.uuid :external_source_id
      t.timestamps
    end
  end
end
