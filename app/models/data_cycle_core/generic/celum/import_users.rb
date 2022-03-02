# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      module ImportUsers
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            ->(_, _, _) { [] },
            ->(_, _, _) { nil },
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, _locale, _options)
          mongo_item.where(:_id.ne => nil)
        end

        def self.extract_data(options, raw_data)
          {
            external_key: "#{options.dig(:import, :external_id_prefix)}#{raw_data['id']}",
            name: [raw_data.dig('firstname').squish, raw_data.dig('lastname').squish].join(' ').squish,
            description: raw_data.dig('email')
          }
        end
      end
    end
  end
end
