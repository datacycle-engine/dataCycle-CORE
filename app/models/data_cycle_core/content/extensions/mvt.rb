# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Mvt
        extend ActiveSupport::Concern

        def to_mvt(x, y, z, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [])
          DataCycleCore::Geo::MvtRenderer.new(x, y, z, contents: self.class.where(id: id).limit(1), simplify_factor: simplify_factor, include_parameters: include_parameters, fields_parameters: fields_parameters, classification_trees_parameters: classification_trees_parameters, single_item: true).render
        end

        class_methods do
          def to_mvt(x, y, z, layer_name: nil, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false)
            DataCycleCore::Geo::MvtRenderer.new(x, y, z, layer_name: layer_name, contents: all, simplify_factor: simplify_factor, include_parameters: include_parameters, fields_parameters: fields_parameters, classification_trees_parameters: classification_trees_parameters, single_item: single_item).render
          end

          def to_bbox
            select_sql = <<-SQL.squish
              json_build_object(
                'xmin', st_xmin(ST_Extent(ST_Collect(things."location", things."line"))),
                'ymin', st_ymin(ST_Extent(ST_Collect(things."location", things."line"))),
                'xmax', st_xmax(ST_Extent(ST_Collect(things."location", things."line"))),
                'ymax', st_ymax(ST_Extent(ST_Collect(things."location", things."line")))
              )
            SQL
            query = all.except(:order).select(select_sql).to_sql

            ActiveRecord::Base.connection.execute(
              Arel.sql(query)
            ).first&.values&.first
          end
        end
      end
    end
  end
end
