# frozen_string_literal: true

module DataCycleCore
  module Content
    module CreateHistory
      def to_history(delete: false, all_translations: false)
        ActiveRecord::Base.connection.execute("SELECT to_thing_history ('#{id}'::UUID, '#{I18n.locale}'::VARCHAR, #{all_translations}::BOOLEAN, #{delete}::BOOLEAN);")
      end
    end
  end
end
