# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      class Webhook < DataCycleCore::Generic::WebhookBase
        def update(data)
          download_config = external_source.config&.dig('download_config')&.symbolize_keys
          import_config = external_source.config&.dig('import_config')&.symbolize_keys

          processed_items = []

          external_data_type = data.first[1]['contentType']
          case external_data_type
          when 'Bild'
            data_name = :images
          when 'Video'
            data_name = :videos
          end

          download_content(download_config: download_config, data_name: data_name, data: data)

          data.each do |language, object|
            next unless ['Bild', 'Video'].include?(object['contentType'])
            processed_items << import_content(import_config: import_config, data_name: data_name, data: object, locale: language)
          end
          processed_items
        end

        def download_content(download_config:, data_name:, data:)
          return if download_config.blank? || data_name.blank? || data.blank?

          full_options = (external_source.default_options || {}).symbolize_keys.merge({ download: download_config.dig(data_name).symbolize_keys.except(:sorting) })
          locales = full_options[:locales] || full_options[:download][:locales] || I18n.available_locales
          download_object = DataCycleCore::Generic::DownloadObject.new(full_options.merge(external_source: external_source, locales: locales))
          id_function = full_options.dig(:download, :download_strategy).constantize.method(:data_id).to_proc
          name_function = full_options.dig(:download, :download_strategy).constantize.method(:data_name).to_proc
          DataCycleCore::Generic::Common::DownloadFunctions.download_single(download_object: download_object, data_id: id_function, data_name: name_function, raw_data: data, options: full_options.deep_symbolize_keys)
        end

        def import_content(import_config:, data_name:, data:, locale:)
          return if import_config.blank? || data_name.blank? || data.blank? || locale.blank?

          full_options = (external_source.default_options || {}).symbolize_keys.merge({ import: import_config.dig(data_name).symbolize_keys.except(:sorting) })
          locales = full_options[:locales] || full_options[:import][:locales] || I18n.available_locales
          import_object = DataCycleCore::Generic::ImportObject.new(full_options.merge(external_source: external_source, locales: locales))
          full_options.dig(:import, :import_strategy).constantize.process_content(utility_object: import_object, raw_data: data, locale: locale, options: full_options.deep_symbolize_keys)
        end

        def create(data)
          update(data)
        end

        def delete(data)
          content_id = data
            .map { |_, content| content['url'] }
            .map { |url| url.split('/').last }
            .uniq
            .first

          contents = DataCycleCore::Thing.where(external_source_id: @external_source.id, external_key: content_id)

          original_id = data
            .map { |_, content| content['contentUrl'] }
            .map { |url| url.split('/')[-3] }
            .uniq
            .reject { |id| id == content_id }
            .first

          DataCycleCore::ContentContent.where(content_b_id: contents.map(&:id)).map(&:content_a).each do |linked_content|
            I18n.with_locale(linked_content.available_locales.first) do
              linked_content.set_data_hash(data_hash: linked_content.get_data_hash)
              linked_content.update(created_at: Time.zone.now)
            end
          end

          if original_id
            original = DataCycleCore::Thing.find_by(external_source_id: @external_source.id, external_key: original_id)

            DataCycleCore::ContentContent.where(content_b_id: contents.map(&:id)).find_each do |content_relation|
              content_relation.update!(content_b_id: original.id) unless DataCycleCore::ContentContent.where(content_a_id: content_relation.content_a_id, content_b_id: original.id, relation_a: content_relation.relation_a).exists?
            end
          end

          duplicated_content_relations = DataCycleCore::ContentContent
            .select(:content_a_id, :relation_a, :content_b_id, 'MIN(created_at) AS "oldest_creation_date"')
            .group(:content_a_id, :relation_a, :content_b_id)
            .having('COUNT(*) > 1')

          duplicated_content_relations.each do |duplicated_relation|
            DataCycleCore::ContentContent.where(
              content_a_id: duplicated_relation.content_a_id,
              relation_a: duplicated_relation.relation_a,
              content_b_id: duplicated_relation.content_b_id
            ).where('created_at > ?', duplicated_relation.oldest_creation_date).destroy_all
          end

          contents.each do |c|
            c.webhook_source = @external_source&.name
            c.original_id = original_id
          end
          contents.map(&:destroy_content).first
        end
      end
    end
  end
end
