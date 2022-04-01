# frozen_string_literal: true

namespace :dc do
  namespace :sync do
    task :switch_primary_source, [:current_primary_source, :new_primary_source, :stored_filter] => :environment do |_, args|
      current_primary_source = DataCycleCore::ExternalSystem.where(id: args[:current_primary_source])
        .or(DataCycleCore::ExternalSystem.where(identifier: args[:current_primary_source]))
        .first
      new_primary_source = DataCycleCore::ExternalSystem.where(id: args[:new_primary_source])
        .or(DataCycleCore::ExternalSystem.where(identifier: args[:new_primary_source]))
        .first

      abort('Unkown or missing current primary source!') if current_primary_source.nil?
      abort('Unkown or missing new primary source!') if new_primary_source.nil?

      contents = DataCycleCore::Thing
        .joins(:external_source, :external_system_syncs)
        .where(external_source_id: current_primary_source.id, external_system_syncs: { external_system_id: new_primary_source.id })

      contents = contents.where(id: DataCycleCore::StoredFilter.find(args[:stored_filter]).apply.select(:id)) if args[:stored_filter]

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'MIGRATING')

      contents.map do |thing|
        ActiveRecord::Base.transaction do
          DataCycleCore::ExternalSystemSync.create_or_find_by!(
            syncable_type: DataCycleCore::Thing,
            syncable_id: thing.id,
            external_system_id: current_primary_source.id,
            external_key: thing.external_key,
            sync_type: 'duplicate'
          )

          external_system_sync = thing.external_system_syncs.where(external_system_id: new_primary_source.id).first

          thing.update!(external_key: external_system_sync.external_key,
                        external_source_id: external_system_sync.external_system_id)

          external_system_sync.destroy!

          progressbar.increment
        end
      end
    end
  end
end
