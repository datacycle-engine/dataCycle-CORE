# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.eyebase_to_bild(external_source_id)
          t(:stringify_keys)
          .>> t(:reject_keys, ['quality_256', 'quality_1024', 'picturepins'])
          .>> t(:unwrap, 'quality_1', ['resolution_x', 'resolution_y', 'size_mb'])
          .>> t(:add_field, 'external_key', ->(s) { s.dig('item_id', 'text') })
          .>> t(:add_field, 'description', ->(s) { s.dig('beschreibung', '#cdata-section') })
          .>> t(:add_field, 'name', ->(s) { s.dig('titel', '#cdata-section') })
          .>> t(:add_field, 'attribution_name', ->(*) { nil })
          .>> t(:add_field, 'license', ->(*) { nil })
          .>> t(:add_link, 'author', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('field_202', '#cdata-section').to_s) })
          .>> t(:add_link, 'copyright_holder', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('copyright', '#cdata-section').to_s) })
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('field_214', '#cdata-section').to_s) })
          .>> t(:add_field, 'restrictions', ->(s) { s.dig('field_224', '#cdata-section') })
          .>> t(:add_field, 'use_guidelines', ->(s) { s.dig('field_216', '#cdata-section') })
          .>> t(:add_field, 'date_created', ->(s) { s.dig('erstellt', '#cdata-section') })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('geaendert', '#cdata-section') })
          .>> t(:add_field, 'width', ->(s) { s.dig('resolution_x', 'text')&.to_i })
          .>> t(:add_field, 'height', ->(s) { s.dig('resolution_y', 'text')&.to_i })
          .>> t(:add_field, 'content_size', ->(s) { s.dig('size_mb', 'text')&.gsub(',', '.')&.to_f&.*(1024)&.*(1024).to_i })
          .>> t(:reject_keys, ['item_id', 'titel', 'field_202', 'field_224', 'copyright', 'field_216', 'resolution_x', 'resolution_y', 'size_mb'])
          .>> t(:add_field, 'content_url', ->(s) { s.dig('main_permalink', '#cdata-section') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('quality_512', 'permalink', '#cdata-section') })
          .>> t(:add_field, 'keywords_eyebase', ->(s) { parse_keywords(s) })
          .>> t(:tags_to_ids, 'keywords_eyebase', external_source_id, 'Eyebase - Tag - ')
          .>> t(:add_link, 'eyebase_lizenz', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('field_227', '#cdata-section').then { |v| v.nil? ? nil : "Eyebase - Lizenz - #{v}" }
          })
          .>> t(:add_link, 'eyebase_folder', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('folder', -1, 'path').then { |v| v.nil? ? nil : "Eyebase - Ordner - #{v}" }
          })
          .>> t(:add_link, 'status_eyebase', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('color', '#cdata-section').then { |v| v.nil? ? nil : "Eyebase - Status - #{v}" }
          })
          .>> t(:reject_keys, ['quality_1', 'quality_512'])
          .>> t(:strip_all)
        end
        # .>> t(:add_field, 'photographer', ->(s) { s.dig('field_202', '#cdata-section') })

        def self.to_video(external_source_id)
          t(:reject_keys, ['picturepins'])
          .>> t(:add_field, 'width', ->(s) { unwrap_video_data(s, 'resolution_x')&.to_i })
          .>> t(:add_field, 'height', ->(s) { unwrap_video_data(s, 'resolution_y')&.to_i })
          .>> t(:add_field, 'duration', ->(s) { unwrap_video_data(s, 'resolution_z')&.to_i })
          .>> t(:add_field, 'content_size', ->(s) { unwrap_video_data(s, 'size_mb')&.gsub(',', '.')&.to_f&.*(1024)&.*(1024)&.to_i })
          .>> t(:add_field, 'file_format', ->(s) { unwrap_video_data(s, 'filename_ext')&.delete('.') })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('item_id', 'text') })
          .>> t(:add_field, 'description', ->(s) { s.dig('beschreibung', '#cdata-section') })
          .>> t(:add_field, 'name', ->(s) { s.dig('titel', '#cdata-section') })
          .>> t(:add_field, 'attribution_name', ->(*) { nil })
          .>> t(:add_field, 'license', ->(*) { nil })
          .>> t(:add_link, 'copyright_holder', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('copyright', '#cdata-section').to_s) })
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('field_214', '#cdata-section').to_s) })
          .>> t(:add_field, 'restrictions', ->(s) { s.dig('field_224', '#cdata-section') })
          .>> t(:add_field, 'use_guidelines', ->(s) { s.dig('field_216', '#cdata-section') })
          .>> t(:add_field, 'date_created', ->(s) { s.dig('erstellt', '#cdata-section') })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('geaendert', '#cdata-section') })
          .>> t(:reject_keys, ['item_id', 'titel', 'field_202', 'field_224', 'copyright', 'field_216', 'resolution_x', 'resolution_y', 'size_mb'])
          .>> t(:add_field, 'content_url', ->(s) { s.dig('field_219', '#cdata-section') || s.dig('field_218', '#cdata-section') })
          .>> t(:add_field, 'url', ->(s) { s.dig('field_219', '#cdata-section') || s.dig('field_218', '#cdata-section') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('quality_256', 'url', '#cdata-section') || s.dig('quality_2', 'permalink', '#cdata-section') || s.dig('quality_1', 'permalink', '#cdata-section') })
          .>> t(:add_field, 'keywords_eyebase', ->(s) { parse_keywords(s) })
          .>> t(:tags_to_ids, 'keywords_eyebase', external_source_id, 'Eyebase - Tag - ')
          .>> t(:add_link, 'eyebase_lizenz', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('field_227', '#cdata-section').then { |v| v.nil? ? nil : "Eyebase - Lizenz - #{v}" }
          })
          .>> t(:add_link, 'eyebase_folder', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('folder', -1, 'path').then { |v| v.nil? ? nil : "Eyebase - Ordner - #{v}" }
          })
          .>> t(:add_link, 'status_eyebase', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('color', '#cdata-section').then { |v| v.nil? ? nil : "Eyebase - Status - #{v}" }
          })
          .>> t(:reject_keys, ['quality_1', 'quality_2', 'quality_256', 'quality_512', 'quality_1024', 'quality_8192'])
        end

        def self.to_audio(external_source_id)
          t(:add_field, 'duration', ->(s) { unwrap_media_data(s, 'resolution_z')&.to_i })
          .>> t(:add_field, 'content_size', ->(s) { unwrap_media_data(s, 'size_mb')&.gsub(',', '.')&.to_f&.*(1024)&.*(1024)&.to_i })
          .>> t(:add_field, 'file_format', ->(s) { unwrap_media_data(s, 'filename_ext')&.delete('.') })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('item_id', 'text') })
          .>> t(:add_field, 'description', ->(s) { s.dig('beschreibung', '#cdata-section') })
          .>> t(:add_field, 'name', ->(s) { s.dig('titel', '#cdata-section') })
          .>> t(:add_field, 'attribution_name', ->(*) { nil })
          .>> t(:add_field, 'license', ->(*) { nil })
          .>> t(:add_link, 'copyright_holder', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('copyright', '#cdata-section').to_s) })
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('field_214', '#cdata-section').to_s) })
          .>> t(:add_field, 'restrictions', ->(s) { s.dig('field_224', '#cdata-section') })
          .>> t(:add_field, 'use_guidelines', ->(s) { s.dig('field_216', '#cdata-section') })
          .>> t(:add_field, 'date_created', ->(s) { s.dig('erstellt', '#cdata-section') })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('geaendert', '#cdata-section') })
          .>> t(:reject_keys, ['item_id', 'titel', 'field_202', 'field_224', 'copyright', 'field_216', 'resolution_x', 'resolution_y', 'size_mb'])
          .>> t(:add_field, 'content_url', ->(s) { s.dig('main_permalink', '#cdata-section') })
          .>> t(:add_field, 'url', ->(s) { s.dig('main_permalink', '#cdata-section') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('quality_512', 'permalink', '#cdata-section') })
          .>> t(:add_field, 'keywords_eyebase', ->(s) { parse_keywords(s) })
          .>> t(:tags_to_ids, 'keywords_eyebase', external_source_id, 'Eyebase - Tag - ')
          .>> t(:add_link, 'eyebase_lizenz', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('field_227', '#cdata-section').then { |v| v.nil? ? nil : "Eyebase - Lizenz - #{v}" }
          })
          .>> t(:add_link, 'eyebase_folder', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('folder', -1, 'path').then { |v| v.nil? ? nil : "Eyebase - Ordner - #{v}" }
          })
          .>> t(:add_link, 'status_eyebase', DataCycleCore::Classification, external_source_id, lambda { |s|
            s.dig('color', '#cdata-section').then { |v| v.nil? ? nil : "Eyebase - Status - #{v}" }
          })
          .>> t(:reject_keys, ['quality_1', 'quality_512', 'quality_1024'])
        end

        def self.unwrap_media_data(s, attribute)
          s.dig('quality_1', attribute, 'text') ||
            s.dig('quality_1024', attribute, 'text') ||
            s.dig('quality_512', attribute, 'text')
        end

        def self.unwrap_video_data(s, attribute)
          s.dig('quality_2', attribute, 'text') || s.dig('quality_1', attribute, 'text')
        end

        def self.eyebase_get_keywords
          t(:add_field, 'keywords', ->(s) { parse_keywords(s) })
        end

        def self.parse_keywords(s)
          [s.dig('field_204', '#cdata-section')&.split(','), s.dig('field_215', '#cdata-section')&.split(',')].flatten.reject(&:nil?).map(&:strip).uniq || []
        end

        def self.get_url(data)
          return nil if data.blank?
          File.join("#{(ActionMailer::Base.default_url_options[:protocol] + '://') if ActionMailer::Base.default_url_options[:protocol].present?}#{ActionMailer::Base.default_url_options[:host]}", 'eyebase', 'media_assets', 'files', data)
        end

        def self.to_organization
          t(:strip_all)
          .>> t(:add_field, 'external_key', ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('name')) })
        end

        def self.to_place
          t(:strip_all)
          .>> t(:add_field, 'external_key', ->(s) { DataCycleCore::MasterData::DataConverter.string_to_string(s.dig('name')) })
        end
      end
    end
  end
end
