# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :export do
    desc 'List available endpoints for import'
    task list: :environment do
      DataCycleCore::ExternalSystem.find_each do |external_system|
        puts "#{external_system.id} - #{external_system.name}"
      end
    end

    desc 'refresh tasks'
    task :refresh, [:external_system_id, :job_id] => [:environment] do |_, args|
      external_system = DataCycleCore::ExternalSystem.find(args[:external_system_id])
      external_system.refresh({ job_id: args.fetch(:job_id, nil) })
    end

    desc 'perform update webhook for given content, content collection or stored filter'
    task :update, [:external_system_id, :id] => [:environment] do |_, args|
      ActiveSupport::Notifications.subscribe(/export\.[^.]*\.datacycle/) do |_name, _started, _finished, _unique_id, data|
        ap data
      end

      external_system = DataCycleCore::ExternalSystem.find(args[:external_system_id])

      contents = DataCycleCore::Thing.where(id: args[:id])
      contents = DataCycleCore::WatchList.where(id: args[:id]).map(&:things).flatten if contents.empty?
      contents = DataCycleCore::StoredFilter.where(id: args[:id]).map { |x| x.apply.to_a }.flatten if contents.empty?

      contents.each do |content|
        puts "Updating #{content.name} (#{content.id}) ..."

        content.allowed_webhooks = [external_system.name]
        content.synchronous_webhooks = true
        content.execute_update_webhooks

        puts "Updating #{content.name} (#{content.id}) ... DONE"
      rescue StandardError => e
        puts "Failed to update #{content.name} (#{content.id}): #{e.message}"
      end
    end
  end
end
