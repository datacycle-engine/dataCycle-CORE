# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module NamedVersion
        def self.extend(router)
          router.instance_exec do
            patch '/things/remove_version_name', action: :remove_version_name, controller: 'things', as: 'remove_version_name'
          end
        end
      end
    end
  end
end
