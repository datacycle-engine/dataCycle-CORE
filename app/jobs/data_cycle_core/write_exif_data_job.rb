# frozen_string_literal: true

require 'mini_exiftool_vendored'

module DataCycleCore
  class WriteExifDataJob < UniqueApplicationJob
    PRIORITY = 12
    WEBHOOK_PRIORITY = 6

    REFERENCE_TYPE = 'write_exif_data'

    EXIF_ARRAY_DATA_TYPES = ['Keywords', 'Subject'].freeze

    queue_as :cache_invalidation

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      REFERENCE_TYPE
    end

    def perform(content_id)
      update_exif_values DataCycleCore::Thing.find_by(id: content_id)
    end

    private

    def update_exif_values(thing)
      asset = thing&.asset
      return if asset.blank?

      asset_path = asset.file.service.path_for(asset.file.key)

      exif_data = MiniExiftool.new(asset_path, { replace_invalid_chars: true, ignore_minor_errors: true })

      updated_values = {}

      I18n.with_locale(thing.first_available_locale) do
        thing.exif_property_names.each do |property_name|
          property_definition = thing.property_definitions.dig(property_name)
          exif_keys = property_definition.dig('exif', 'keys')
          exif_value = thing.send(property_name)

          if property_definition['type'] == 'linked'
            exif_value = exif_value.map(&:name).join(', ')
          elsif property_definition['type'] == 'classification'
            exif_value = exif_value.map(&:name)
          end

          next if exif_keys.blank? || exif_value.blank?

          exif_value = property_definition.dig('exif', 'prepend') + exif_value if property_definition.dig('exif', 'prepend')
          exif_value += property_definition.dig('exif', 'prepend') if property_definition.dig('exif', 'append')

          exif_keys.each do |key|
            if exif_value.is_a?(Array) && EXIF_ARRAY_DATA_TYPES.exclude?(key)
              exif_data[key] = exif_value.join(',')
            else
              exif_data[key] = exif_value
            end
            updated_values[key] = exif_data[key]
          end
        end
      end

      return unless exif_data.changed?

      exif_data.save
      update_variants(thing, updated_values)
    rescue MiniExiftool::Error
      nil
    end

    def update_variants(thing, updated_values)
      image_variant_property_names = thing.name_property_selector { |definition| definition['type'] == 'embedded' && ['ImageVariant', 'ImageObjectVariant'].include?(definition['template_name']) }
      return if image_variant_property_names.blank?

      image_variants = thing.send(image_variant_property_names.first)

      I18n.with_locale(thing.first_available_locale) do
        image_variants.each do |variant|
          asset = variant.asset
          next if asset.blank?

          asset_path = asset.file.service.path_for(asset.file.key)

          exif_data = MiniExiftool.new(asset_path, { replace_invalid_chars: true, ignore_minor_errors: true })

          updated_values['Headline'] = variant.name || updated_values['Headline']

          updated_values.each do |k, v|
            exif_data[k] = v
          end

          next unless exif_data.changed?

          exif_data.save
          variant.invalidate_self
        end
      end
    end
  end
end
