# frozen_string_literal: true

module DataCycleCore
  module BaseSchema
    def self.params(**options, &block)
      Dry::Schema.Params(**options) do
        config.messages.default_locale = :en
        config.messages.backend = :i18n
        config.messages.top_namespace = 'dry_validation'

        instance_eval(&block) if block
      end
    end
  end
end
