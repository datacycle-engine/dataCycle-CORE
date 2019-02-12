# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.document_to_bild(external_source_id)
          t(:stringify_keys)
          .>> t(:compact)
          .>> t(:strip_all)
        end
      end
    end
  end
end
