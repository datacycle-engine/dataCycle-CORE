# frozen_string_literal: true

module DataCycleCore
  module Content
    module Restorable
      def restore
        content_id = thing_id

        translations.each do |translated_entry|
          DataCycleCore::Thing::Translation.create(translated_entry.attributes.slice(*DataCycleCore::Thing::Translation.column_names.except('id')).merge('thing_id' => content_id))
        end

        content = DataCycleCore::Thing.create(attributes.slice(*DataCycleCore::Thing.column_names).merge('id' => thing_id))

        binding.pry

        destroy
      end
    end
  end
end
