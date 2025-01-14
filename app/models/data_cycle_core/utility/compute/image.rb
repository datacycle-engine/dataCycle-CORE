# frozen_string_literal: true

require 'fastimage'

module DataCycleCore
  module Utility
    module Compute
      module Image
        class << self
          def width(**args)
            local_width(**args)
          end

          def local_width(computed_parameters:, **_args)
            image = DataCycleCore::Image.where(id: computed_parameters.values).first

            orientation = exif_value(image, ['Orientation'])

            if orientation&.include?('90') || orientation&.include?('270')
              exif_value(image, ['ImageHeight'])&.to_i
            else
              exif_value(image, ['ImageWidth'])&.to_i
            end
          end

          def remote_width(**args)
            remote_value(**args) do |remote_image|
              remote_image&.size&.first
            end
          end

          def local_or_remote_width(**args)
            local_width(**args) || remote_width(**args)
          end

          def height(**args)
            local_height(**args)
          end

          def local_height(computed_parameters:, **_args)
            image = DataCycleCore::Image.where(id: computed_parameters.values).first

            orientation = exif_value(image, ['Orientation'])

            if orientation&.include?('90') || orientation&.include?('270')
              exif_value(image, ['ImageHeight'])&.to_i
            else
              exif_value(image, ['ImageWidth'])&.to_i
            end
          end

          def remote_height(**args)
            remote_value(**args) do |remote_image|
              remote_image&.size&.last
            end
          end

          def local_or_remote_height(**args)
            local_height(**args) || remote_height(**args)
          end

          def local_file_size(computed_parameters:, **_args)
            DataCycleCore::Asset.where(id: computed_parameters.values).first&.try(:file_size)&.to_i
          end

          def remote_file_size(**args)
            remote_value(**args, &:content_length)
          end

          def local_or_remote_file_size(**args)
            local_file_size(**args) || remote_file_size(**args)
          end

          def aspect_ratio(computed_parameters:, **_args)
            computed_parameters['width'].to_f / computed_parameters['height'].to_f # rubocop:disable Style/FloatDivision
          end

          def aspect_ratio_classification(computed_parameters:, computed_definition:, **_args)
            return if computed_parameters.blank? || computed_definition.dig('compute', 'min_values').blank?

            ratios = []

            computed_parameters.each_value do |aspect_ratio|
              computed_definition.dig('compute', 'min_values').each do |h|
                break ratios.push(h.keys.first) if aspect_ratio >= h.values.first
              end
            end

            return if ratios.blank?

            DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(computed_definition['tree_label'], ratios)
          end

          def thumbnail_url(computed_parameters:, **_args)
            DataCycleCore::ActiveStorageService.with_current_options do
              DataCycleCore::Image.find_by(id: computed_parameters.values.first)&.thumb_preview&.url
            end
          end

          def exif_value(image, path)
            image = DataCycleCore::Image.find_by(id: image) unless image.is_a?(DataCycleCore::Image)
            return nil if image.blank? || path.blank?
            image&.metadata&.dig(*path)
          end

          def remote_value(computed_parameters:, data_hash:, content:, key:, **_args)
            url_key, new_url = computed_parameters.find { |_, v| v.is_a?(::String) && v =~ URI::DEFAULT_PARSER.make_regexp }
            old_url = content&.send(url_key)

            old_value = content&.send(key)

            if data_hash[key].present?
              data_hash[key]
            elsif old_value.nil? || old_url != new_url
              @remote_images ||= {}
              @remote_images[new_url] = FastImage.new(new_url)
              yield(@remote_images[new_url])
            else
              old_value
            end
          end
        end
      end
    end
  end
end
