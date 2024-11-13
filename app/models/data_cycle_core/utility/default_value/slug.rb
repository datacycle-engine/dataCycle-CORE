# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Slug
        class << self
          def generate_slug(content:, data_hash:, **_args)
            value = content.title(data_hash:)&.to_slug
            DataCycleCore::MasterData::DataConverter.generate_slug(value || content.slug, content, data_hash)
          end
        end
      end
    end
  end
end
