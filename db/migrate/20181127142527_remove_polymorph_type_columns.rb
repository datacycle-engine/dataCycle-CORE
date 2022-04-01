# frozen_string_literal: true

class RemovePolymorphTypeColumns < ActiveRecord::Migration[5.1]
  def up
    remove_column :classification_contents, :content_data_type
    remove_column :classification_content_histories, :content_data_history_type

    remove_column :content_contents, :relation_b
    remove_column :content_contents, :order_b
    remove_column :content_contents, :content_a_type
    remove_column :content_contents, :content_b_type

    remove_column :content_content_histories, :relation_b
    remove_column :content_content_histories, :order_b
    remove_column :content_content_histories, :content_a_history_type

    remove_column :searches, :content_data_type

    remove_index :searches, [:locale, :content_data_id]
    add_index :searches, [:content_data_id, :locale], unique: true
  end

  def down
    remove_index :searches, [:content_data_id, :locale]
    add_index :searches, [:locale, :content_data_id]

    add_column :searches, :content_data_type, :string, default: 'DataCycleCore::Thing', null: false

    add_column :content_content_histories, :content_a_history_type, :string, default: 'DataCycleCore::Thing::History', null: false
    add_column :content_content_histories, :order_b, :integer
    add_column :content_content_histories, :relation_b, :string

    add_column :content_contents, :content_b_type, :string, default: 'DataCycleCore::Thing', null: false
    add_column :content_contents, :content_a_type, :string, default: 'DataCycleCore::Thing', null: false
    add_column :content_contents, :order_b, :integer
    add_column :content_contents, :relation_b, :string

    add_column :classification_content_histories, :content_data_history_type, :string, default: 'DataCycleCore::Thing::History', null: false
    add_column :classification_contents, :content_data_type, :string, default: 'DataCycleCore::Thing', null: false
  end
end
