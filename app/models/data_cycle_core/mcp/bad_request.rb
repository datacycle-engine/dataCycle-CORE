# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # A parameter error of a tool call, in exactly the shape Mcp::ErrorMapper translates into the
    # same {errors: [{source:, title:, detail:}]} response as the REST API
    # (DataCycleCore::ErrorHandler).
    #
    # A shared module, because otherwise every caller builds the hash itself (Mcp::AttributeFilter,
    # Mcp::SortScope, Mcp::ContentWriter, Tools::Download): four copies of the same three-part
    # shape, each of which can drift from the contract on its own. And the drift is not visible but
    # silent -- without :type the ErrorMapper falls back to `detail` for the `title`, so the
    # response carries the same text twice instead of a translated heading.
    module BadRequest
      # The error type when the caller names none: an argument whose value is not allowed. Other
      # types (e.g. 'invalid_format', 'validation_error') double as the key under
      # exceptions.data_cycle_core/error/api/bad_request_error.* for the translated title.
      DEFAULT_TYPE = 'invalid_parameter'

      private

      # @param parameter_path [String] path of the rejected argument, e.g. 'attributes[0]', 'sort.attribute'
      # @param detail [String] what the client passed wrongly -- this text goes to the client
      # @param type [String] error type, see above
      # @raise [DataCycleCore::Error::Api::BadRequestError]
      def bad_request!(parameter_path, detail, type = DEFAULT_TYPE)
        raise DataCycleCore::Error::Api::BadRequestError.new({ parameter_path:, type:, detail: }), 'API Bad Request Error'
      end
    end
  end
end
