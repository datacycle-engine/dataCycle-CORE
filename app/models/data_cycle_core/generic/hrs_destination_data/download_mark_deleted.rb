# frozen_string_literal: true

module DataCycleCore
  module Generic
    module HrsDestinationData
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
          dtstart = data.dig('event', 'firstDate').try(:in_time_zone)
          return true if dtstart.blank?
          dtend = data.dig('event', 'lastDate').try(:in_time_zone)
          (dtend.blank? || dtend < deadline) && (dtstart < deadline)
        end
      end
    end
  end
end