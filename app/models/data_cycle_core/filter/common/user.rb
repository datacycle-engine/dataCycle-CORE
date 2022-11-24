# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module User
        def user(ids = nil, type = nil)
          return self if type.blank?

          send(type, ids)
        end

        def not_user(ids = nil, type = nil)
          return self if type.blank?

          send("not_#{type}", ids)
        end

        def creator(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(thing[:created_by].in(ids))
          )
        end

        def not_creator(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(thing[:created_by].in(ids))
          )
        end

        def last_editor(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(thing[:updated_by].in(ids))
          )
        end

        def not_last_editor(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(thing[:updated_by].in(ids))
          )
        end

        def editor(ids = nil)
          return self if ids.blank?

          thing_query = DataCycleCore::Thing.where(updated_by: ids).select(:id).arel
          thing_history_query = DataCycleCore::Thing::History.where(updated_by: ids).select(:thing_id).arel

          reflect(
            @query.where(thing[:id].in(Arel::Nodes::UnionAll.new(thing_query, thing_history_query)))
          )
        end

        def not_editor(ids = nil)
          return self if ids.blank?

          thing_query = DataCycleCore::Thing.where(updated_by: ids).select(:id).arel
          thing_history_query = DataCycleCore::Thing::History.where(updated_by: ids).select(:thing_id).arel

          reflect(
            @query.where.not(thing[:id].in(Arel::Nodes::UnionAll.new(thing_query, thing_history_query)))
          )
        end
      end
    end
  end
end
