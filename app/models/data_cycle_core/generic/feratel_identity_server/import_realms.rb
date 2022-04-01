# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelIdentityServer
      module ImportRealms
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

        def self.extract_data(_options, raw_data)
          {
            external_key: "REALM:#{raw_data['code']}",
            name: raw_data.dig('code'),
            description: raw_data.dig('name')
          }
        end
      end
    end
  end
end
