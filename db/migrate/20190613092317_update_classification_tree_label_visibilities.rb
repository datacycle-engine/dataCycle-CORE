# frozen_string_literal: true

class UpdateClassificationTreeLabelVisibilities < ActiveRecord::Migration[5.1]
  def up
    DataCycleCore::ClassificationTreeLabel.where.not(name: ['Inhaltspools', 'Inhaltstypen']).update(visibility: ['show', 'edit', 'tile', 'api'])
    DataCycleCore::ClassificationTreeLabel.where(name: ['Inhaltspools']).update(visibility: ['api'])
  end

  def down
    DataCycleCore::ClassificationTreeLabel.all.update(visibility: [''])
  end
end
