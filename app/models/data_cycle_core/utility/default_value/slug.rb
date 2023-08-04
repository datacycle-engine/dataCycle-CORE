# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Slug
        class << self
          def generate_slug(content:, data_hash:, **_args)
            value = content.title(data_hash:)&.to_slug
            content.convert_to_type('slug', value || content.slug)
          end
        end
      end
    end
  end
end
