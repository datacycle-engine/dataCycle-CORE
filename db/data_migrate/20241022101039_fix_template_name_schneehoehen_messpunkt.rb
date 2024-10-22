# frozen_string_literal: true

# rubocop:disable Rails/Output
class FixTemplateNameSchneehoehenMesspunkt < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    name_mapping = {
      'Scheehöhenmesspunkt' => 'Schneehöhenmesspunkt',
      'freie Scheehöhenmesspunkte' => 'freie Schneehöhenmesspunkte'
    }

    name_mapping.each do |old_name, new_name|
      ca = DataCycleCore::ClassificationAlias.find_by(internal_name: old_name)
      next unless ca
      ca_new = DataCycleCore::ClassificationAlias.find_by(internal_name: new_name)
      ca.merge_with_children(ca_new)
    end
  end

  def down
  end
end

# rubocop:enable Rails/Output
