# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module Translate
        def self.extend(router)
          router.instance_exec do
            post '/things/translate_text', action: :translate_text, controller: 'things', as: 'translate_text_thing'
          end
        end
      end
    end
  end
end
