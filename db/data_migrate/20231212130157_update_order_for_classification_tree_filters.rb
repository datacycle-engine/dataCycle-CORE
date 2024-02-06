# frozen_string_literal: true

class UpdateOrderForClassificationTreeFilters < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    tree_labels_to_sort = Array.wrap(DataCycleCore.features.dig('main_filter', 'config', 'backend', 'filter')&.reduce(&:merge)&.dig('classification_trees')).except('Nutzungsrechte')

    return if tree_labels_to_sort.blank?

    DataCycleCore::RunTaskJob.perform_now('dc:classifications:update:sort_alphabetically', [tree_labels_to_sort.join('|')])
  end

  def down
  end
end
