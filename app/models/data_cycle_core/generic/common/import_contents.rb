# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportContents
        extend DataCycleCore::Generic::Common::Transformations::TransformationUtilities

        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object:,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options:
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
            data_module = options.dig(:import, :data_filter, :module) || options[:transformations]
            data_filter = options.dig(:import, :data_filter, :method)
            return if data_module.blank?
            return if data_filter.present? && !data_module.constantize.method(data_filter).call(raw_data, options.dig(:import, :data_filter))

            Array.wrap(options.dig(:import, :nested_contents)).each do |nested_contents_config|
              transformation = options[:transformations].constantize.method(nested_contents_config[:transformation])

              Array.wrap(resolve_attribute_path(raw_data, nested_contents_config[:path])).each do |nested_data|
                next if nested_contents_config[:exists].present? && Array.wrap(nested_contents_config[:exists]).map { |path| resolve_attribute_path(nested_data, path).blank? }.inject(:|)

                # ap transformation.call(utility_object.external_source.id).call(nested_data)

                nested_content_config = nested_contents_config.except(:exists, :path, :template, :transformation)
                raw_data = raw_data.merge(options.dig(:import, :main_content, :data)) if options.dig(:import, :main_content, :data).present?
                process_single_content(utility_object, nested_contents_config[:template], transformation, nested_data, nested_content_config)
              end
            end

            transformation = options[:transformations].constantize
              .method(options.dig(:import, :main_content, :transformation))

            # ap transformation.call(utility_object.external_source.id).call(raw_data).with_indifferent_access

            main_content_config = options.dig(:import, :main_content).except(:template, :transformation)
            raw_data = raw_data.merge(options.dig(:import, :main_content, :data)) if options.dig(:import, :main_content, :data).present?
            process_single_content(utility_object, options.dig(:import, :main_content, :template), transformation, raw_data, main_content_config)
          end
        end

        def self.process_single_content(utility_object, template_name, transformation, raw_data, config = {})
          return if DataCycleCore::DataHashService.deep_blank?(raw_data)
          return if raw_data.keys.size == 1 && raw_data.keys.first.in?(['id', '@id'])

          template = DataCycleCore::Generic::Common::ImportFunctions.load_template(template_name)

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object:,
            template:,
            data: transformation.call(transformation.parameters.dig(0, 1).to_s.end_with?('_id') ? utility_object.external_source.id : utility_object.external_source).call(raw_data).with_indifferent_access,
            config:
          )
        end
      end
    end
  end
end
