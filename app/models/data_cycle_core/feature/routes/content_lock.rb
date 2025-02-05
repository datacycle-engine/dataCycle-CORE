# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module ContentLock
        def self.extend(router)
          router.instance_exec do
            get '/things/:id/check_lock', action: :check_lock_thing, controller: 'things', as: 'check_lock_thing'
            get '/watch_lists/:id/check_lock', action: :check_lock_watch_list, controller: 'watch_lists', as: 'check_lock_watch_list'
          end
        end
      end
    end
  end
end
