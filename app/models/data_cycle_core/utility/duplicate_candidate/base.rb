# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class Base
        include ActiveModel::Model

        FEATURE = DataCycleCore::Feature::DuplicateCandidate
        PARAMETERS = [].freeze

        class << self
          # def duplicates(content:, **)
          #   raise NotImplementedError, "You must implement #{self.class}##{__method__}"
          # end

          def parameters(**)
            self::PARAMETERS
          end

          def identifier
            name.demodulize.underscore
          end

          def feature
            self::FEATURE
          end

          def by_identifier(identifier)
            DataCycleCore::ModuleService.load_module(identifier.classify, 'Utility::DuplicateCandidate')
          end

          def to_select_option(locale = DataCycleCore.ui_locales.first)
            DataCycleCore::Filter::SelectOption.new(
              id: identifier,
              name: model_name.human(count: 1, locale:),
              html_class: identifier,
              dc_tooltip: model_name.human(count: 1, locale:),
              class_key: identifier
            )
          end
        end
      end
    end
  end
end
