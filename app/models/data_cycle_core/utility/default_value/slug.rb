# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Slug
        class << self
          def generate_slug(content:, data_hash:, **_args)
            content.try(:slug).presence&.to_s&.to_slug ||
              content&.title(data_hash:).presence&.to_slug ||
              I18n.t('common.no_name')
          end
        end
      end
    end
  end
end
