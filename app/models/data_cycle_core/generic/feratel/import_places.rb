# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportPlaces
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where("dump.#{locale}": { '$exists' => true }.merge(source_filter))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            ['categories', 'data_owners_accommodations', 'holiday_themes', 'classifications', 'stars'].each do |name_tag|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', name_tag).deep_symbolize_keys }
              )
            end

            DataCycleCore::Generic::Feratel::Processing.process_image(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :image)
            )
            DataCycleCore::Generic::Feratel::Processing.process_accommodation(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )

            # topics = [raw_data.dig('Details', 'Topics', 'Topic')].flatten.reject(&:nil?).map { |t|
            #   DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: t['Id'].downcase)
            # }.reject(&:nil?)

            # holiday_themes = [raw_data.dig('Details', 'HolidayThemes', 'Item')].flatten.reject(&:nil?).map { |t|
            #   DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: t['Id'].downcase)
            # }.reject(&:nil?)

            # facilities = [raw_data.dig('Facilities', 'Facility')].flatten.reject(&:nil?).map { |f|
            #   DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: f['Id'].downcase)
            # }.reject(&:nil?)

            # accommodation_categories = [raw_data.dig('Details', 'Categories', 'Item')].flatten.reject(&:nil?).map { |c|
            #   DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: c['Id'].downcase)
            # }.reject(&:nil?)

            # feratel_classifications = [raw_data.dig('Details', 'Classifications', 'Item')].flatten.reject(&:nil?).map { |c|
            #   DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: c['Id'].downcase)
            # }.reject(&:nil?)
            #
            # stars = [raw_data.dig('Details', 'Stars')].flatten.reject(&:nil?).map { |s|
            #   DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: s['Id'].downcase)
            # }.reject(&:nil?)
            #
            # owners = [raw_data.dig('Details', 'DataOwner')].flatten.reject(&:nil?).map { |s|
            #   DataCycleCore::Classification.find_by(external_source_id: external_source.id,
            #                                         external_key: "OWNER:#{Digest::MD5.hexdigest(s.is_a?(String) ? s : s['text'])}")
            # }.reject(&:nil?)

            # create_or_update_content(
            #   @target_type,
            #   load_template(@target_type, @data_template),
            #   extract_place_data(raw_data).with_indifferent_access.merge(
            #     data_type: nil,
            #     image: images.map(&:id),
            #     topics: topics.map(&:id),
            #     holiday_themes: holiday_themes.map(&:id),
            #     facilities: facilities.map(&:id),
            #     accommodation_categories: accommodation_categories.map(&:id),
            #     feratel_classifications: feratel_classifications.map(&:id),
            #     stars: stars.map(&:id),
            #     feratel_owners: owners.map(&:id)
            #   ).with_indifferent_access
            # )
          end
        end
      end
    end
  end
end
