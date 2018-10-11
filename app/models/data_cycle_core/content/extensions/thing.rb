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
          when 'Place'
            name.presence || address_line || coordinates || I18n.t('common.no_translation', locale: DataCycleCore.ui_language)
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
          when 'Place'
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
          when 'Place'
            ['address', 'location']
          end
        end

        def address_line
          "#{address.postal_code} #{address.address_locality}, #{address.street_address}" if try(:address)&.to_h&.values&.presence&.any?(&:present?)
        end

        def coordinates
          "#{latitude}, #{longitude}" if latitude.present? && longitude.present?
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
