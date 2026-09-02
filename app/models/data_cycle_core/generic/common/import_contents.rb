# frozen_string_literal: true

require 'jsonpath'

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

        def self.load_contents(filter_object:)
          filter_object.with_locale.without_deleted.query
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            data_module = options.dig(:import, :data_filter, :module) || options[:transformations]
            data_filter = options.dig(:import, :data_filter, :method)
            return if data_module.blank?
            return if data_filter.present? && !data_module.constantize.method(data_filter).call(raw_data, options.dig(:import, :data_filter))

            # nested contents are cut out of the mongo document and carry no key of their own, so the
            # document's key is handed down -- otherwise their dc_mongo_key names no document at all
            base_external_id = DataCycleCore::Generic::Common::ImportFunctions.mongo_external_id(raw_data)

            Array.wrap(options.dig(:import, :nested_contents)).each do |nested_contents_config|
              transformation_method = options[:transformations].constantize.method(nested_contents_config[:transformation])

              nested_content_filter_module = nested_contents_config.dig(:filter, :module)
              nested_content_filter_method = nested_contents_config.dig(:filter, :method)

              nested_contents_items = if nested_contents_config[:json_path].present?
                                        JsonPath.new(nested_contents_config[:json_path]).on(raw_data).flatten
                                      else
                                        resolve_attribute_path(raw_data, nested_contents_config[:path])
                                      end

              Array.wrap(nested_contents_items).each do |nested_data|
                next if nested_contents_config[:exists].present? && Array.wrap(nested_contents_config[:exists]).map { |path| resolve_attribute_path(nested_data, path).blank? }.inject(:|)
                next if nested_contents_config[:not_exists].present? && Array.wrap(nested_contents_config[:not_exists]).map { |path| resolve_attribute_path(nested_data, path).present? }.inject(:|)
                next if nested_content_filter_module && nested_content_filter_method && !nested_content_filter_module.constantize.method(nested_content_filter_method).call(nested_data)

                nested_content_config = nested_contents_config.except(:exists, :not_exists, :path, :json_path, :template, :transformation)
                raw_data = raw_data.merge(options.dig(:import, :main_content, :data)) if options.dig(:import, :main_content, :data).present?
                process_single_content(utility_object, nested_contents_config[:template], transformation_method, nested_data, nested_content_config, base_external_id:)
              end
            end

            transformation_method = options[:transformations].constantize.method(options.dig(:import, :main_content, :transformation))
            main_content_config = options.dig(:import, :main_content).except(:template, :transformation)
            raw_data = raw_data.merge(options.dig(:import, :main_content, :data)) if options.dig(:import, :main_content, :data).present?
            process_single_content(utility_object, options.dig(:import, :main_content, :template), transformation_method, raw_data, main_content_config)
          end
        end

        # +base_external_id+ is set for nested contents only, and merged in only once the two guards
        # ran: they judge the payload as it came in, a key of ours makes every hash look present.
        def self.process_single_content(utility_object, template_name, transformation_method, raw_data, config = {}, base_external_id: nil)
          return if DataCycleCore::DataHashService.deep_blank?(raw_data)
          return if raw_data.keys.size == 1 && raw_data.keys.first.in?(['id', '@id'])

          # merged, not written in place: nested data is a part of the base data the main content still gets
          raw_data = raw_data.merge('dc_external_id' => base_external_id) if base_external_id.present?

          transformation = transformation_with_args(transformation_method:, utility_object:, config:)

          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object:,
            raw_data:,
            transformation:,
            default: { template: template_name },
            config: utility_object.step_config(config)
          )
        end
      end
    end
  end
end
