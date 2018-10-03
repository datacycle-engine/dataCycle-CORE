# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Event
        extend ActiveSupport::Concern

        def title
          # TODO: remove later
          return name if respond_to?(:name) && name.present?
          headline if respond_to?(:headline) && headline.present?
        end

        def desc
          description
        end

        def new_content_fields
          ['name']
        end

        def object_browser_fields
          ['name']
        end

        module ClassMethods
          # TODO: remove from_time (implemented in DataCycleCore::Filter::Search)
          def from_time(time)
            time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
            where(arel_table[:end_date].gteq(Arel::Nodes.build_quoted(time.iso8601)))
          end

          # TODO: remove to_time (implemented in DataCycleCore::Filter::Search)
          def to_time(time)
            time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
            where(arel_table[:start_date].lteq(Arel::Nodes.build_quoted(time.iso8601)))
          end

          # TODO: remove sort_by_proximity (implemented in DataCycleCore::Filter::Search)
          def sort_by_proximity(date = Time.zone.now)
            order(absolute_date_diff(arel_table[:end_date], Arel::Nodes.build_quoted(date.iso8601)),
                  absolute_date_diff(arel_table[:start_date], Arel::Nodes.build_quoted(date.iso8601)),
                  :start_date)
          end
        end
      end
    end
  end
end
