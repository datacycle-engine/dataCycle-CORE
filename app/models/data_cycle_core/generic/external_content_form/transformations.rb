# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ExternalContentForm
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.transformation
          t(:stringify_keys)
          .>> t(:underscore_keys)
          .>> t(:rename_keys, {
            'title' => 'name'
          })
          .>> t(:accept_keys, ['email', 'given_name', 'family_name', 'name'])
        end
      end
    end
  end
end
