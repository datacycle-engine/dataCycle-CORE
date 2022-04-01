# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      module ImportEventImages
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}": { '$exists' => true } }.merge(source_filter))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            next if raw_data.dig('images').blank?
            teaser = raw_data.dig('images', 'teaser')
            size = raw_data.dig('images', 'gallery').size
            image_urls = ([raw_data.dig('images', 'teaser')].compact + raw_data.dig('images', 'gallery').map { |item| item.dig('link') }.compact).uniq
            image_urls.each_with_index do |image_url, index|
              image_hash = { 'link' => image_url }
              image_hash['index'] = index + 1
              image_hash['gallery_size'] = size
              image_hash['name'] = image_url.split('/').last
              image_hash['teaser'] = true if image_url == teaser
              DataCycleCore::Generic::Pimcore::Processing.process_event_image(
                utility_object,
                image_hash,
                options.dig(:import, :transformations, :image)
              )
            end
          end
        end
      end
    end
  end
end
