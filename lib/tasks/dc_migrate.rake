# frozen_string_literal: true

namespace :dc do
  namespace :migrate do
    desc 'move external_source_id and external_key from things to external_system_syncs'
    task :external_source_to_system, [:external_system_id] => :environment do |_, args|
      external_system_id = args[:external_system_id]

      exit(-1) if external_system_id.blank?

      contents = DataCycleCore::Thing.where(external_source_id: external_system_id).where.not(external_key: nil)

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      contents.find_each do |content|
        content.external_source_to_external_system_syncs

        progressbar.increment
      end
    end
  end
end
