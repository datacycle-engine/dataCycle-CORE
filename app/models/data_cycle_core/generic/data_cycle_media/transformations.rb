# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleMedia
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.file_to_asset
          t(:stringify_keys)
          .>> t(:tags_to_ids_by_name, 'tags', 'Tags')
          .>> t(:strip_all)
        end
      end
    end
  end
end
