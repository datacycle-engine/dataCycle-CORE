# frozen_string_literal: true

namespace :dc do
  namespace :statistics do
    desc 'output template names and frequency in Thing and Thing::History'
    task template_statistics: :environment do
      statistics, history = DataCycleCore::MasterData::ImportTemplates.template_statistics
      ap statistics
      ap history
    end
  end
end
