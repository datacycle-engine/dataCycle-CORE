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

      utility_object = DataCycleCore::Export::PushObject.new(action: :update, external_system:)

      contents = DataCycleCore::Thing.where(id: args[:id])
      contents = DataCycleCore::WatchList.where(id: args[:id]).map(&:things).flatten if contents.empty?
      contents = DataCycleCore::StoredFilter.where(id: args[:id]).map { |x| x.apply.to_a }.flatten if contents.empty?

      webhook_class = external_system.export_config[:webhook].constantize

      contents.each do |content|
        puts "Updating #{content.name} (#{content.id}) ..."

        webhook = webhook_class.new(
          data: content.tap { |c| c.updated_at = Time.zone.now },
          method: (external_system.config.dig('export_config', 'update', 'method') || external_system.config.dig('export_config', 'method') || :put).to_sym,
          body: nil,
          endpoint: utility_object.endpoint,
          transformation: external_system.config.dig('export_config', 'update', 'transformation') || external_system.config.dig('export_config', 'transformation') || :json_partial,
          path: utility_object.endpoint.path_transformation(content, external_system, 'update'),
          utility_object:,
          type: 'update',
          locale: I18n.locale
        )
        webhook.perform

        webhook.success(webhook)

        puts "Updating #{content.name} (#{content.id}) ... DONE"
      rescue DataCycleCore::Export::Common::Error::GenericError => e
        webhook.failure(webhook)

        puts "Failed to update #{content.name} (#{content.id}): #{e.message}"
      end
    end
  end
end
