# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Mvt
        extend ActiveSupport::Concern

        def to_mvt(x, y, z, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], cache: true)
          DataCycleCore::Geo::MvtRenderer.new(
            x,
            y,
            z,
            contents: self.class.where(id:).limit(1),
            simplify_factor:,
            include_parameters:,
            fields_parameters:,
            classification_trees_parameters:,
            single_item: true,
            cache:
          ).render
        end

        class_methods do
          def to_mvt(x, y, z, layer_name: nil, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false, cache: true, cluster: false, cluster_lines: false, cluster_items: false, cluster_layer_name: nil)
            DataCycleCore::Geo::MvtRenderer.new(
              x,
              y,
              z,
              layer_name:,
              contents: all,
              simplify_factor:,
              include_parameters:,
              fields_parameters:,
              classification_trees_parameters:,
              single_item:,
              cache:,
              cluster:,
              cluster_lines:,
              cluster_items:,
              cluster_layer_name:
            ).render
          end

          def to_bbox
            select_sql = <<-SQL.squish
              json_build_object(
                'xmin', st_xmin(ST_Extent(things.geom_simple)),
                'ymin', st_ymin(ST_Extent(things.geom_simple)),
                'xmax', st_xmax(ST_Extent(things.geom_simple)),
                'ymax', st_ymax(ST_Extent(things.geom_simple))
              )
            SQL
            query = all.except(:order, :limit, :offset).select(select_sql).to_sql

            ActiveRecord::Base.connection.execute(Arel.sql(query)).first&.values&.first
          end
        end
      end
    end
  end
end
