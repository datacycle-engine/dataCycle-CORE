# frozen_string_literal: true

module DataCycleCore
  module Feature
    # The duplicate button in the header of a saved embedded: EmbeddedObject renders a split-view
    # copy below it, and the save creates a second record. UI only, so #enabled? is the whole gate.
    class DuplicateEmbedded < Base
    end
  end
end
