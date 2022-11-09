# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Mvt
        extend ActiveSupport::Concern

        class_methods do
          def to_mvt(x, y, z, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false)
            DataCycleCore::Geo::MvtRenderer.new(x, y, z, contents: all, simplify_factor: simplify_factor, include_parameters: include_parameters, fields_parameters: fields_parameters, classification_trees_parameters: classification_trees_parameters, single_item: single_item).render
          end
        end

        # TODO: Caching
        # def geojson_cache_key
        #   "#{self.class.name.underscore}/#{id}_#{I18n.locale}_#{updated_at.to_i}_#{cache_valid_since.to_i}"
        # end
      end
    end
  end
end
