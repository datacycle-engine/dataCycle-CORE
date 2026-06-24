# frozen_string_literal: true

module DataCycleCore
  # Builds a lightweight, anonymous Struct instance to stand in for a value
  # object in (helper) unit tests, e.g. struct_double(name: 'x', id: 1).
  # Used instead of OpenStruct so the tests stay within Style/OpenStructUse.
  module StructDoubleHelper
    def struct_double(**attributes)
      Struct.new(*attributes.keys).new(*attributes.values)
    end
  end
end

ActiveSupport.on_load(:active_support_test_case) { include DataCycleCore::StructDoubleHelper }
