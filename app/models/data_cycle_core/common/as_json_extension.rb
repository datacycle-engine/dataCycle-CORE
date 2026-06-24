# frozen_string_literal: true

module DataCycleCore
  module Common
    # Extends as_json behavior with camelCase key transformation support.
    #
    # This module provides a custom as_json implementation that allows automatic conversion
    # of hash keys from snake_case to camelCase format when serializing objects to JSON.
    # This is particularly useful for API responses that need to follow JavaScript/JSON
    # naming conventions while maintaining Rails snake_case conventions in the codebase.
    #
    # Include this module in any model or class that needs camelCase JSON serialization.
    #
    # @example Basic usage
    #   class User < ApplicationRecord
    #     include DataCycleCore::Common::AsJsonExtension
    #   end
    #
    #   user.as_json(camelize_keys: true)
    #   # => { "firstName" => "John", "createdAt" => "2026-04-16" }
    module AsJsonExtension
      # Overrides as_json to support camelCase key transformation.
      # Pass `camelize_keys: true` to convert all keys to camelCase.
      def as_json(options = {})
        return super unless options[:camelize_keys] == true

        super.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      end
    end
  end
end
