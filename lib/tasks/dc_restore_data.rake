# frozen_string_literal: true

namespace :dc do
  namespace :restore do
    namespace :contents do
      desc 'restore contents from history with thing_ids [UUID|UUID|UUID|...]'
      task :from_ids, [:ids] => [:environment] do |_, args|
        ids = args.fetch(:ids, '').split('|').map(&:squish)

        abort('no ids given') if ids.blank?

        to_restore = DataCycleCore::Thing::History.where(thing_id: ids).where.not(deleted_at: nil)
        progressbar = ProgressBar.create(total: to_restore.size, format: '%t |%w>%i| %a - %c/%C', title: 'Restoring')

        to_restore.find_each do |history_entry|
          history_entry.restore

          progressbar.increment
        end
      end
    end
  end
end
