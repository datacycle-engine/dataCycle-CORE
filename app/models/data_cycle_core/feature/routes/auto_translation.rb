# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module AutoTranslation
        def self.extend(router)
          router.instance_exec do
            post '/things/:id/create_auto_translations', action: :create_auto_translations, controller: 'things', as: 'create_auto_translations_thing'
            post '/things/:id/auto_translations', action: :auto_translations, controller: 'things', as: 'auto_translations_thing'
          end
        end
      end
    end
  end
end
