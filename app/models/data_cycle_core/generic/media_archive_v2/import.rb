# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchiveV2
      module Import
        def import_data(**options)
          @place_template = options[:import][:place_template] || 'Örtlichkeit'
          @person_template = options[:import][:person_template] || 'Person'
          load_transformations
          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_transformations
          @image_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_v2_to_bild(external_source.id)
          @video_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_v2_to_video(external_source.id)
          @content_location_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_v2_to_content_location
          @person_transformation = DataCycleCore::Generic::Transformations::Transformations.media_archive_to_person
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            content_location = create_or_update_content(
              DataCycleCore::Place,
              load_template(DataCycleCore::Place, @place_template),
              extract_content_location_data(raw_data['contentLocation'])
                .merge({ 'external_key' => "#{raw_data['contentType']}-#{@place_template}: #{raw_data['url'].split('/').last}" }).with_indifferent_access
            )

            director = create_or_update_content(
              DataCycleCore::Person,
              load_template(DataCycleCore::Person, @person_template),
              extract_person_data(raw_data['director'])
                .merge({ 'external_key' => "Regie: #{raw_data['url'].split('/').last}" }).with_indifferent_access
            )

            contributor = create_or_update_content(
              DataCycleCore::Person,
              load_template(DataCycleCore::Person, @person_template),
              extract_person_data(raw_data['contributor'])
                .merge({ 'external_key' => "Kamera: #{raw_data['url'].split('/').last}" }).with_indifferent_access
            )

            raw_data['content_location'] = [content_location.try(:id)] if content_location.present?
            raw_data['director'] = [director.try(:id)] if director.present?
            raw_data['contributor'] = [contributor.try(:id)] if contributor.present?

            case raw_data['contentType']
            when 'Bild'
              data = extract_image_data(raw_data).with_indifferent_access
            when 'Video'
              data = extract_video_data(raw_data).with_indifferent_access
            else
              data = nil
              ap "Unkown contentType #{raw_data}"
            end
            default_values = load_default_values(@options.dig(:import, :default_values)) if @options.dig(:import, :default_values).present?
            data.merge!(default_values) if default_values.present?

            unless data.nil?
              create_or_update_content(
                @target_type,
                template,
                data
              )
            end
          end
        end

        def extract_image_data(raw_data)
          raw_data.nil? ? {} : @image_transformation.call(raw_data)
        end

        def extract_video_data(raw_data)
          raw_data.nil? ? {} : @video_transformation.call(raw_data)
        end

        def extract_content_location_data(raw_data)
          return {} if raw_data.nil? || (raw_data['address'].blank? && (raw_data['geo'].blank? || (raw_data['geo']['latitude'] == 0.0 && raw_data['geo']['longitude'] == 0.0)))
          @content_location_transformation.call(raw_data)
        end

        def extract_person_data(raw_data)
          raw_data.nil? ? {} : @person_transformation.call(raw_data)
        end
      end
    end
  end
end
