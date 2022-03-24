# frozen_string_literal: true

module DataCycleCore
  class FilterService
    def self.update_pg_dict_mappings
      return unless ActiveRecord::Base.connection.table_exists?('pg_dict_mappings')

      missing_locales = I18n.available_locales.map(&:to_s) - PgDictMapping.all.pluck(:locale)

      return if missing_locales.blank?

      PgDictMapping.create(missing_locales.map { |v| { locale: v, dict: 'pg_catalog.simple' } })
    rescue ActiveRecord::NoDatabaseError
      nil
    end
  end
end
