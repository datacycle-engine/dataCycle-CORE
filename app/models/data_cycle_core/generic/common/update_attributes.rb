# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module UpdateAttributes
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object.tap { |obj| obj.mode = :full },
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}": { '$exists': true } }.merge(source_filter.with_evaluated_values))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          last_success = utility_object.external_source.last_successful_download
          raise 'No successful download detected!' if last_success.blank?

          last_download = utility_object.external_source.last_download
          raise "Last download(s) failed! Last success: #{last_success}, last try: #{last_download}" if last_download.present? && last_success < last_download

          delete_deadline = eval(options.dig(:import, :last_successful_download)) if options.dig(:import, :last_successful_download).present? # rubocop:disable Security/Eval
          if delete_deadline.present? && last_success < delete_deadline
            last_date = last_success.presence || 'never'
            delete_date = delete_deadline.presence || 'not specified'
            raise "No recent successful download detected! Last successful Download: #{last_date}, delete deadline: #{delete_date}"
          end

          I18n.with_locale(locale) do
            external_key_path = options.dig(:import, :external_key_path).split('.')

            raise "No external id found! Item:#{raw_data.dig('Id')}, external_key_path: #{external_key_path}" if raw_data.dig(*external_key_path).blank?

            update_item = DataCycleCore::Thing.find_by(
              external_source_id: utility_object.external_source.id,
              external_key: raw_data.dig(*external_key_path)
            )

            update_hash = {}
            options.dig(:import, :attributes).each do |attribute|
              next unless update_item.respond_to?(attribute.dig(:key)&.to_s)
              value = load_value_for_attribute(attribute)
              update_hash[attribute.dig(:key)] = value if value.present?
            end

            update_item.set_data_hash(partial_update: true, prevent_history: false, data_hash: update_hash) if update_hash.present?
          end
        end

        def self.load_value_for_attribute(attribute)
          case attribute.dig(:type)
          when 'classification'
            value = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
              .where('classification_tree_labels.name = ?', attribute.dig(:tree_label))
              .where('classification_aliases.internal_name = ?', attribute.dig(:value)).first!.id
            [value] || nil
          when 'float'
            attribute.dig(:value).to_f
          when 'integer'
            attribute.dig(:value).to_i
          when 'string'
            attribute.dig(:value).to_s
          end
        end
      end
    end
  end
end