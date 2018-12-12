# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Thing
        extend ActiveSupport::Concern

        def title
          case schema_type
          when 'Organization', 'Event', 'CreativeWork'
            name
          when 'Person'
            "#{given_name} #{family_name}"
          when 'Place'
            name.presence || I18n.t('common.no_translation', locale: DataCycleCore.ui_language)
          end
        end

        def desc
          case schema_type
          when 'Organization', 'Event', 'CreativeWork'
            description
          when 'Person'
            content['job_title']
          end
        end

        def object_browser_fields
          # title is shown by default
          case schema_type
          when 'Organization', 'Event', 'CreativeWork'
            []
          when 'Person'
            ['honorific_prefix', 'job_title', 'contact_info']
          when 'Place'
            ['address']
          end
        end

        def address_line
          return if schema_type != 'Place'
          (try(:address)&.postal_code.present? || try(:address)&.address_locality.present? ? "#{address.postal_code} #{address.address_locality}, " : '') + (try(:address)&.street_address.present? ? address.street_address : '')
        end

        def address_block
          return if schema_type != 'Place'
          ((try(:address)&.postal_code.present? || try(:address)&.address_locality.present? ? "#{address.postal_code} #{address.address_locality}<br>" : '') + (try(:address)&.street_address.present? ? address.street_address&.gsub(', ', '<br>') : ''))
        end

        def coordinates
          "GPS: #{latitude.round(2)}, #{longitude.round(2)}" if latitude.present? && longitude.present?
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
