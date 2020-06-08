# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleApiV4
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::DataCycleApiV4::Functions[*args]
        end

        def self.transformation
          t(:stringify_keys)
          .>> t(:rename_keys, { '@id' => 'id' })
          .>> t(:reject_keys, ['@type'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
