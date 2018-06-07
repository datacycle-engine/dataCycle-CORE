# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module Processing
        def process_media_asset(raw_data, config)
          type = config.dig('content_type').constantize || DataCycleCore::CreativeWork
          template = config.dig(:template) || 'Bild'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::Eyebase::Transformations
              .eyebase_to_bild(external_source.id)
              .call(raw_data)
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
