# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Mvt
        extend ActiveSupport::Concern

        def to_mvt(x, y, z, **kwargs)
          DataCycleCore::Geo::MvtRenderer.new(x, y, z, contents: self.class.where(id:).limit(1), **kwargs).render
        end

        class_methods do
          def to_mvt(x, y, z, **kwargs)
            DataCycleCore::Geo::MvtRenderer.new(x, y, z, contents: all, **kwargs).render
          end

          def to_bbox
            select_sql = <<-SQL.squish
              json_build_object(
                'xmin', st_xmin(ST_Extent(geometries.geom_simple)),
                'ymin', st_ymin(ST_Extent(geometries.geom_simple)),
                'xmax', st_xmax(ST_Extent(geometries.geom_simple)),
                'ymax', st_ymax(ST_Extent(geometries.geom_simple))
              )
            SQL
            query = DataCycleCore::Geometry
              .where(thing_id: all.except(:order, :limit, :offset).select(:id))
              .select(select_sql)
              .to_sql

            ActiveRecord::Base.connection.select_all(Arel.sql(query)).first&.values&.first
          end
        end
      end
    end
  end
end
