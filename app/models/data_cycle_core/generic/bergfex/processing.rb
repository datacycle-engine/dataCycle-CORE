# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Processing
        def process_lakes(raw_data, config)
          type = config.dig(:content_type).constantize || DataCycleCore::Place
          template = config.dig(:template) || 'See'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::Bergfex::Transformations
              .bergfex_to_see
              .call(raw_data)
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
