# frozen_string_literal: true

require 'data_cycle_core/engine'

module DataCycleCore
  # This will prevent the Rails Engine from generating all table prefixes with the engines name
  def self.table_name_prefix
  end
end
