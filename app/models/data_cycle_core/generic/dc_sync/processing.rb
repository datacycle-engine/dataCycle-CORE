# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Processing
        def self.process_things(utility_object, raw_data, template, config)
          # data_type = DataCycleCore::Thing.find_by(template_name: template, template: false)
          processed_thing = nil
          raw_data.except('included', 'attribute_name', 'include_translation').each_key do |locale|
            I18n.with_locale(locale) do
              # filter for now all linked_data
              # sync_data = raw_data[locale]
              # sync_data = sync_data.except(*data_type.linked_property_names)
              processed_thing = DataCycleCore::Generic::Common::ImportFunctions.process_step(
                utility_object: utility_object,
                raw_data: raw_data[locale].merge(raw_data.slice('include_translation')),
                transformation: DataCycleCore::Generic::DcSync::Transformations.to_thing(utility_object.external_source.id),
                default: { template: template },
                config: config
              )
            end
          end
          processed_thing
        end
      end
    end
  end
end
