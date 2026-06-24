# frozen_string_literal: true

module DataCycleCore
  class ModuleService
    class << self
      def load_module(module_name, module_path = nil, safe = false)
        found_module = find_module("#{module_path}::#{module_name}") if module_path.present?
        found_module ||= find_module(module_name)

        raise LoadError, "Module #{module_path}::#{module_name} not found!" unless found_module || safe

        found_module
      end

      def safe_load_module(module_name, module_path = nil)
        load_module(module_name, module_path, true)
      end

      def find_module(full_path)
        return Module.const_get("::#{full_path}") if Module.const_defined?("::#{full_path}")

        Rails.application.railties.each do |railtie|
          nested_path = "#{railtie.class.module_parent_name}::#{full_path}"
          return Module.const_get(nested_path) if Module.const_defined?(nested_path)
        end

        nil
      end
    end
  end
end
