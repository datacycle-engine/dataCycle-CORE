# frozen_string_literal: true

module DataCycleCore
  class ModuleService
    class << self
      def load_module(module_name, module_path)
        return Module.const_get("::#{module_path}::#{module_name}") if Module.const_defined?("::#{module_path}::#{module_name}")
        return Module.const_get("DataCycleCore::#{module_path}::#{module_name}") if Module.const_defined?("DataCycleCore::#{module_path}::#{module_name}")
        return Module.const_get("::#{module_name}") if Module.const_defined?("::#{module_name}")

        Module.const_get("DataCycleCore::#{module_name}")
      end
    end
  end
end
