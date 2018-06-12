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
          .>> t(:reject_keys, ['quality_256', 'quality_1024', 'picturepins', 'ordnerstruktur'])
          .>> t(:unwrap, 'quality_1', ['resolution_x', 'resolution_y', 'size_mb'])
          .>> t(:add_field, 'external_key', ->(s) { s.dig('item_id', 'text') })
          .>> t(:add_field, 'description', ->(s) { s.dig('beschreibung', '#cdata-section') })
          .>> t(:add_field, 'headline', ->(s) { s.dig('titel', '#cdata-section') })
          .>> t(:add_field, 'photographer', ->(s) { s.dig('field_202', '#cdata-section') })
          .>> t(:add_field, 'license', ->(s) { s.dig('copyright', '#cdata-section') })
          .>> t(:add_field, 'restrictions', ->(s) { s.dig('field_216', '#cdata-section') })
          .>> t(:add_field, 'width', ->(s) { s.dig('resolution_x', 'text')&.to_i })
          .>> t(:add_field, 'height', ->(s) { s.dig('resolution_y', 'text')&.to_i })
          .>> t(:add_field, 'content_size', ->(s) { s.dig('size_mb', 'text')&.gsub(',', '.')&.to_f&.*(1024)&.*(1024).to_i })
          .>> t(:reject_keys, ['item_id', 'titel', 'field_202', 'copyright', 'field_216', 'resolution_x', 'resolution_y', 'size_mb'])
          .>> t(
            :add_field, 'content_url',
            lambda do |s|
              begin
                File.join("#{(ActionMailer::Base.default_url_options[:protocol] + '://') if ActionMailer::Base.default_url_options[:protocol].present?}#{ActionMailer::Base.default_url_options[:host]}", 'eyebase', 'media_assets', 'files', s.dig('quality_1', 'filename', 'text'))
              rescue StandardError
                nil
              end
            end
          )
          .>> t(
            :add_field, 'thumbnail_url',
            lambda do |s|
              begin
                File.join("#{(ActionMailer::Base.default_url_options[:protocol] + '://') if ActionMailer::Base.default_url_options[:protocol].present?}#{ActionMailer::Base.default_url_options[:host]}", 'eyebase', 'media_assets', 'files', s.dig('quality_512', 'filename', 'text'))
              rescue StandardError
                nil
              end
            end
          )
          .>> t(:add_field, 'keywords_eyebase', ->(s) { parse_keywords(s) })
          .>> t(:tags_to_ids, 'keywords_eyebase', external_source_id, 'Eyebase - Tag - ')
          .>> t(:reject_keys, ['quality_1', 'quality_512'])
          .>> t(:compact)
          .>> t(:strip_all)
        end

        def self.eyebase_get_keywords
          t(:add_field, 'keywords', ->(s) { parse_keywords(s) })
        end

        def self.parse_keywords(s)
          [s.dig('field_204', '#cdata-section')&.split(','), s.dig('field_215', '#cdata-section')&.split(',')].flatten.reject(&:nil?).map(&:strip).uniq || []
        end
      end
    end
  end
end
