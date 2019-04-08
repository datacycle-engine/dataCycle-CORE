# frozen_string_literal: true

namespace :dc do
  namespace :statistics do
    desc 'update all computed attributes'
    task template_statistics: :environment do
      statistics, history = DataCycleCore::MasterData::ImportTemplates.template_statistics
      ap statistics
      ap history
    end
  end
end
