# frozen_string_literal: true

raise 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#initialize_type_map is no longer available, check patch!' unless ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.private_method_defined? :initialize_type_map

module PostgresCustomTypesExtension
  def initialize_type_map(m)
    m.alias_type 'regconfig', 'varchar'
    super(m)
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend PostgresCustomTypesExtension
end
