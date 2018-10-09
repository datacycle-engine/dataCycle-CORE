# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Thing
        extend ActiveSupport::Concern

        def title
          case schema_type
          when 'Organization'
            name
          when 'Person'
            "#{given_name} #{family_name}"
          when 'Event'
            name
          end
        end

        def desc
          case schema_type
          when 'Organization'
            description
          when 'Person'
            content['job_title']
          when 'Event'
            description
          end
        end

        def new_content_fields
          case schema_type
          when 'Organization'
            ['name']
          when 'Person'
            ['given_name', 'family_name']
          when 'Event'
            ['name']
          end
        end

        def object_browser_fields
          case schema_type
          when 'Organization'
            []
          when 'Person'
            ['given_name', 'family_name', 'honorific_prefix', 'job_title', 'contact_info']
          when 'Event'
            []
          end
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
