# frozen_string_literal: true

module DataCycleCore
  module Generic
    module JetTicket
      module DownloadMarkDeleted
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.mark_deleted_from_data(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            archived: method(:archive?).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(
            I18n.with_locale(locale) { source_filter.with_evaluated_values }
              .merge({
                "dump.#{locale}" => { '$exists' => true },
                "dump.#{locale}.deleted_at" => { '$exists' => false },
                "dump.#{locale}.archived_at" => { '$exists' => false }
              })
          )
        end

        def self.archive?(data, deadline)
          dtstart = data.dig('DateTime').try(:in_time_zone)
          return true if dtstart.blank?
          duration = Time.zone.parse(data.dig('Duration')) - Time.new(1900).in_time_zone
          dtend = dtstart + duration
          (dtend < deadline) && (dtstart < deadline)
        end
      end
    end
  end
end
