# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      class Webhook < DataCycleCore::Export::Common::Webhook
        def perform
          @endpoint.log_request(
            data: @data,
            body: @body,
            method: @method
          )
        end

        def queue_name
          "text_file_#{@data.id}"
        end
      end
    end
  end
end
