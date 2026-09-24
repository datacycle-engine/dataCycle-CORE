# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Prompts
      # "How many / which X are there?" -- the question on which a client most reliably produces a
      # plausible wrong number: full-text search instead of facets, one variant of a term instead of
      # all of them, limit instead of sorting, and finally a number without the filter it came from.
      # The prompt ties exactly those four steps to the question.
      class InventoryQuestion < Base
        self.prompt_name = 'inventory_question'
        self.description_key = 'inventory_question'
        self.argument_keys = [:question]
      end
    end
  end
end
