# frozen_string_literal: true

namespace :dc do
  namespace :statistics do
    desc 'update all computed attributes'
    task template_statistics: :environment do
      statistics = DataCycleCore::MasterData::ImportTemplates.template_statistics
      ap statistics
    end
  end
end
