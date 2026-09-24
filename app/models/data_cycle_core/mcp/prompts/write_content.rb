# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Prompts
      # Creating or changing a content. Registered only when write_enabled is set -- a prompt that
      # appears in the client's selection list is a promise that the server can do it; visible
      # without the write tools it would be an invitation into an error.
      #
      # The prompt IS the explicit user instruction that create_content/update_content require: it
      # is deliberately selected in the client, unlike a wish voiced in passing during a
      # conversation. That is why the confirmation rule is not repeated here.
      class WriteContent < Base
        self.prompt_name = 'write_content'
        self.description_key = 'write_content'
        self.argument_keys = [:intent]
      end
    end
  end
end
