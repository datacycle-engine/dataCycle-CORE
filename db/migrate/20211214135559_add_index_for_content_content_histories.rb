# frozen_string_literal: true

class AddIndexForContentContentHistories < ActiveRecord::Migration[5.2]
  def change
    add_index :content_content_histories, :content_a_history_id
  end
end
