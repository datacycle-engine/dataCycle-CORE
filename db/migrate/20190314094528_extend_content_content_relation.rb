# frozen_string_literal: true

class ExtendContentContentRelation < ActiveRecord::Migration[5.1]
  def change
    add_column :content_contents, :relation_b, :string
    add_column :content_content_histories, :relation_b, :string
  end
end
