# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TranslationOfWork < Base
      class << self
        def data_hash_module
          DataCycleCore::Feature::DataHash::TranslationOfWork
        end
      end
    end
  end
end
