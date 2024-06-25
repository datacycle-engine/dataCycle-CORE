# frozen_string_literal: true

raise 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#initialize_type_map is no longer available, check patch!' unless ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.private_method_defined? :initialize_type_map

module PostgresCustomTypesExtension
  def initialize_type_map(m)
    # regconfig to tsvector
    m.register_type('regconfig', ActiveRecord::Type::String.new)

    # multirange types
    m.register_type('int4multirange', ActiveRecord::Type::String.new)
    m.register_type('int8multirange', ActiveRecord::Type::String.new)
    m.register_type('nummultirange', ActiveRecord::Type::String.new)
    m.register_type('datemultirange', ActiveRecord::Type::String.new)
    m.register_type('tsmultirange', ActiveRecord::Type::String.new)
    m.register_type('tstzmultirange', ActiveRecord::Type::String.new)

    super(m)
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend PostgresCustomTypesExtension
end
