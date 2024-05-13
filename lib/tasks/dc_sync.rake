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

    desc 'trigger webhooks for all things in collection not previously exported'
    task :trigger_webhooks, [:endpoint_id_or_slug, :external_system_id, :force] => :environment do |_, args|
      abort('endpoint missing!') if args.endpoint_id_or_slug.blank?
      abort('external_system_id missing!') if args.external_system_id.blank?

      force = args.force.to_s == 'true'

      collection = DataCycleCore::Collection.by_id_or_slug(args.endpoint_id_or_slug).first
      abort('endpoint not found!') if collection.nil?

      external_system = DataCycleCore::ExternalSystem.find_by(id: args.external_system_id)
      abort('external_system not found!') if external_system.nil?

      things = collection.things
      things = things.where.not(DataCycleCore::ExternalSystemSync.where(syncable_type: 'DataCycleCore::Thing', sync_type: 'export', external_system_id: external_system.id).where('external_system_syncs.syncable_id = things.id').select(1).arel.exists) unless force

      things.find_each do |thing|
        thing.allowed_webhooks = [external_system.name]
        thing.execute_update_webhooks
      end
    end
  end
end
