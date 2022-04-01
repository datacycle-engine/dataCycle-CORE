# frozen_string_literal: true

module DataCycleCore
  class WatchListDataHash < ApplicationRecord
    belongs_to :watch_list, touch: true
    belongs_to :hashable, polymorphic: true

    # after_commit :notify_data_links, on: [:create, :destroy], unless: proc { |w| w.watch_list.destroyed? }
    # if this is re-enabled, change @watch_list.watch_list_data_hashes.clear to @watch_list.watch_list_data_hashes.destroy_all

    private

    def notify_data_links
      watch_list.valid_write_links.each do |data_link|
        if Delayed::Job.find_by(queue: 'mailers', delayed_reference_type: 'updated_watch_list_items', delayed_reference_id: data_link.id, locked_by: nil).present?
          Delayed::Job.find_by(queue: 'mailers', delayed_reference_type: 'updated_watch_list_items', delayed_reference_id: data_link.id, locked_by: nil).update(run_at: 5.minutes.from_now)
        else
          DataLinkMailer.delay(queue: 'mailers', run_at: 5.minutes.from_now, delayed_reference_id: data_link.id, delayed_reference_type: 'updated_watch_list_items').updated_items(data_link)
        end
      end
    end
  end
end
