# frozen_string_literal: true

module DataCycleCore
  module Feature
    class AutoTranslation < Base
      class << self
        def data_hash_module
          DataCycleCore::Feature::DataHash::AutoTranslation
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::AutoTranslation
        end

        def allowed?(content = nil)
          false if content.blank?
          enabled? && content.respond_to?(:additional_information) && content.respond_to?(:subject_of)
        end
      end
    end
  end
end
