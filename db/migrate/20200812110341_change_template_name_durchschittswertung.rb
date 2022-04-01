# frozen_string_literal: true

class ChangeTemplateNameDurchschittswertung < ActiveRecord::Migration[5.2]
  def up
    DataCycleCore::Thing.where(template_name: 'Durchschittswertung').update_all(template_name: 'Durchschnittswertung')
    DataCycleCore::Thing::History.where(template_name: 'Durchschittswertung').update_all(template_name: 'Durchschnittswertung')
    DataCycleCore::Search.where(data_type: 'Durchschittswertung').update_all(data_type: 'Durchschnittswertung')
  end

  def down
    DataCycleCore::Thing.where(template_name: 'Durchschnittswertung').update_all(template_name: 'Durchschittswertung')
    DataCycleCore::Thing::History.where(template_name: 'Durchschnittswertung').update_all(template_name: 'Durchschittswertung')
    DataCycleCore::Search.where(data_type: 'Durchschnittswertung').update_all(data_type: 'Durchschittswertung')
  end
end
