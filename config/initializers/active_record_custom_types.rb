# frozen_string_literal: true

raise 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#initialize_type_map is no longer available, check patch!' unless ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.private_method_defined? :initialize_type_map

module PostgresCustomTypesExtension
  extend ActiveSupport::Concern

  class_methods do
    def initialize_type_map(m)
      # regconfig to tsvector
      m.alias_type 'regconfig', 'varchar'

      # multirange types
      m.alias_type 'int8multirange', 'varchar'
      m.alias_type 'int4multirange', 'varchar'
      m.alias_type 'nummultirange', 'varchar'
      m.alias_type 'datemultirange', 'varchar'
      m.alias_type 'tsmultirange', 'varchar'
      m.alias_type 'tstzmultirange', 'varchar'

      super
    end
  end
end

ActiveSupport.on_load(:active_record_postgresqladapter) { prepend PostgresCustomTypesExtension }
