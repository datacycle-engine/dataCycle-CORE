# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Cleanup
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.logging_without_mongo(
            utility_object: utility_object,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.process_content(utility_object, options)
          items_count = 0
          external_source_id = utility_object.external_source.id
          dependent_types = options.dig(:import, :dependent_types)
          dependent_types.each do |template_name|
            items = DataCycleCore::Thing
              .left_joins(:content_a)
              .where(template_name: template_name, external_source_id: external_source_id, content_contents: { id: nil })
            items_count += items.count
            items.find_each { |content| content.destroy_content(destroy_linked: true, destroy_locale: false) }
          end
          items_count
        end
      end
    end
  end
end
