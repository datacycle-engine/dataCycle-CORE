# frozen_string_literal: true

class TransformToAdditionalDescription < ActiveRecord::Migration[5.2]
  def up
    DataCycleCore::ContentContent
      .where(relation_a: 'subject_of')
      .joins(:content_a)
      .where(things: { template_name: ['Service'] })
      .update_all(relation_a: 'additional_information')
  end

  def down
    DataCycleCore::ContentContent
      .where(relation_a: 'additional_information')
      .joins(:content_a)
      .where(things: { template_name: ['Service'] })
      .update_all(relation_a: 'subject_of')
  end
end
