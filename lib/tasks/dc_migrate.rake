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

    desc 'download external assets into dataCycle'
    task :download_external_assets, [:external_system_id] => :environment do |_, args|
      logger = Logger.new('log/download_assets.log')
      logger.info('Started Downloading...')

      external_system_id = args[:external_system_id]
      allowed_template_names = DataCycleCore::Thing.where(template: true).where("things.schema -> 'properties' ->> 'asset' IS NOT NULL").pluck(:template_name)

      logger.error('External System not found or no viable Templates found') && exit(-1) if external_system_id.blank? || allowed_template_names.blank?

      contents = DataCycleCore::Thing.left_joins(:assets).by_external_system(external_system_id).where(template_name: allowed_template_names).where(assets: { id: nil })

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')
      logger.info("Downloading assets for #{contents.size} contents...")

      contents.find_each do |content|
        I18n.with_locale(content.first_available_locale) do
          asset_type = content.schema&.dig('properties', 'asset', 'asset_type')
          logger.warn("missing asset_type for #{content.id}") && next if asset_type.blank?

          file_url = content.try(:content_url)
          logger.warn("missing content_url for #{content.id}") && next if file_url.blank?

          asset = DataCycleCore.asset_objects.find { |a| a == "DataCycleCore::#{asset_type.classify}" }&.safe_constantize&.new(name: content.title, remote_file_url: file_url)

          logger.error("asset for #{content.id} not saved: #{asset.errors&.full_messages}") && next unless asset&.save

          valid = content.set_data_hash(data_hash: {
            asset: asset.id
          }, partial_update: true, prevent_history: true, update_search_all: false)

          if valid[:error].present?
            logger.error("Error saving content: #{valid[:error]}")
          else
            logger.info("Successfully loaded asset for #{content.id} from #{file_url}")
          end

          progressbar.increment
        end
      end

      logger.info('Finished Downloading...')
    end
  end
end
