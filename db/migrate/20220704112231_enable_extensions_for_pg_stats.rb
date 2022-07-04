# frozen_string_literal: true

class EnableExtensionsForPgStats < ActiveRecord::Migration[6.1]
  def change
    enable_extension 'pg_stat_statements' unless extension_enabled?('pg_stat_statements')
    enable_extension 'pg_buffercache' unless extension_enabled?('pg_buffercache')
  end
end
