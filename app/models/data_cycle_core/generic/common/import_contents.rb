# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportContents
        extend DataCycleCore::Generic::Common::TransformationUtilities

        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(
            I18n.with_locale(locale) { source_filter.with_evaluated_values }
              .merge(
                "dump.#{locale}": { '$exists': true },
                "dump.#{locale}.deleted_at": { '$exists': false }
              )
          )
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            Array.wrap(options.dig(:import, :nested_contents)).each do |nested_contents_config|
              transformation = options[:transformations].constantize
                .method(nested_contents_config[:transformation])

              Array.wrap(resolve_attribute_path(raw_data, nested_contents_config[:path])).each do |nested_data|
                process_single_content(utility_object, nested_contents_config[:template], transformation, nested_data)
              end
            end

            transformation = options[:transformations].constantize
              .method(options.dig(:import, :main_content, :transformation))

            process_single_content(utility_object, options.dig(:import, :main_content, :template), transformation, raw_data)
          end
        end

        def self.process_single_content(utility_object, template_name, transformation, raw_data)
          return if raw_data.blank?
          return if raw_data.keys.size == 1 && raw_data.keys.first.in?(['id', '@id'])

          template = DataCycleCore::Generic::Common::ImportFunctions.load_template(template_name)

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: template,
            data: transformation.call(utility_object.external_source.id).call(raw_data).with_indifferent_access
          )
        end
      end
    end
  end
end
