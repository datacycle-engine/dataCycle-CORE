# frozen_string_literal: true

# remove after https://github.com/shioyama/mobility/issues/678 is fixed

if ActiveRecord::VERSION::MAJOR >= 8
  Mobility::Plugins::ActiveRecord::Query::QueryExtension.module_eval do
    def select_for_count
      return super unless klass.respond_to?(:mobility_attribute?)

      # Check if any select values are Mobility attribute aliases
      has_mobility_aliases = select_values.any? do |value|
        value.respond_to?(:right) && value.right.start_with?(ATTRIBUTE_ALIAS_PREFIX)
      end

      return super unless has_mobility_aliases

      # Filter out Mobility aliases, replacing them with the underlying columns
      filtered_select_values = select_values.map do |value|
        value.respond_to?(:right) && value.right.start_with?(ATTRIBUTE_ALIAS_PREFIX) ? value.left : value
      end

      # Copied from lib/active_record/relation/calculations.rb
      with_connection do |conn|
        arel_columns(filtered_select_values).map { |column| conn.visitor.compile(column) }.join(', ')
      end
    end
  end
end
