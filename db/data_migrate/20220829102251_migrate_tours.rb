# frozen_string_literal: true

class MigrateTours < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return unless DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_internal_name('Tour').exists?

    filter = DataCycleCore::StoredFilter.new.parameters_from_hash(
      [with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Tour'] }]
    ).tap(&:save!)

    DataCycleCore::RunTaskJob.perform_later('dc:migrate:external_to_univeral_classifications', filter.id)
    DataCycleCore::RunTaskJob.perform_later('dc:migrate:pull_classifications_from_embedded', [filter.id, 'schedule', 'by_month', 'universal_classifications'])
    DataCycleCore::RunTaskJob.perform_later('dc:migrate:tours', filter.id)
  end

  def down
  end
end
