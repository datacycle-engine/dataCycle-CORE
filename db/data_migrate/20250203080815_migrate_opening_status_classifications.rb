# frozen_string_literal: true

class MigrateOpeningStatusClassifications < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  CA_MAPPING = {
    'Closed' => 'geschlossen',
    'NoInformation' => 'keine Informationen',
    'Open' => 'geöffnet',
    'WeekendOnly' => 'nur am Wochenende geöffnet'
  }.freeze

  def up
    old_cas = DataCycleCore::Concept.for_tree('OpeningStatus')
    new_cas = DataCycleCore::Concept.for_tree('Öffnungsstatus').index_by(&:internal_name)

    return if old_cas.blank? || new_cas.blank?

    old_cas.each do |old_ca|
      new_ca = new_cas[CA_MAPPING[old_ca.internal_name]]
      next if new_ca.blank?

      old_ca.classification_alias.merge_with_children(new_ca.classification_alias)
    end

    DataCycleCore::ClassificationTreeLabel.find_by(name: 'OpeningStatus')&.destroy
  end

  def down
  end
end
