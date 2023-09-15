# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Image
        class << self
          def width(computed_parameters:, **_args)
            exif_value(computed_parameters.values.first, ['ImageWidth'])&.to_i
          end

          def height(computed_parameters:, **_args)
            exif_value(computed_parameters.values.first, ['ImageHeight'])&.to_i
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
            ActiveStorage::Current.set(host: Rails.application.config.asset_host) do
              DataCycleCore::Image.find_by(id: computed_parameters.values.first)&.thumb_preview&.url
            end
          end

          def exif_value(image_id, path)
            image = DataCycleCore::Image.find_by(id: image_id)
            return nil if image.blank? || path.blank?
            image&.metadata&.dig(*path)
          end
        end
      end
    end
  end
end
