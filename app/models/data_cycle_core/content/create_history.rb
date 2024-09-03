# frozen_string_literal: true

module DataCycleCore
  module Content
    module CreateHistory
      def to_history(delete: false, all_translations: false)
        return if embedded?

        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.send(
            :sanitize_sql_array,
            [
              'SELECT to_thing_history (?::UUID, ?::VARCHAR, ?::BOOLEAN, ?::BOOLEAN);',
              id,
              last_updated_locale || I18n.available_locales.first.to_s,
              all_translations,
              delete
            ]
          )
        )
      end
    end
  end
end
