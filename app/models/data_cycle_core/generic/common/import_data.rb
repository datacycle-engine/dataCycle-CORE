# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportData
        def delete_data(utility_object:, iterator:, data_processor:, options:)
          init_logging(utility_object) do |logging|
            utility_object.with_mongodb do
              each_locale(utility_object.locales) do |locale|
                step_label = utility_object.step_label(options.merge({ locales: [locale] }))

                begin
                  logging.phase_started(step_label)

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    filter_object = Import::FilterObject.new(nil, locale, mongo_item, binding)
                      .with_deleted
                    filter_object = filter_object.with_deleted_since(utility_object.last_successful_try) if utility_object.mode == :incremental && utility_object.last_successful_try.present?

                    iterate = filtered_items(iterator, locale, filter_object)
                    external_key_path = options.dig(:import, :external_key_path)
                    iterate = iterate.only("dump.#{locale}.#{external_key_path}") if external_key_path.present?

                    total = iterate.size
                    data = iterate.to_a
                    start_time = Time.current

                    result = data_processor.call(utility_object: utility_object, raw_data: data, locale: locale, options: options)
                    total = result if result.is_a?(Numeric)
                    total = 0 if result.blank?

                    logging.phase_finished(step_label, total, Time.current - start_time)
                  rescue StandardError => e
                    logging.phase_failed(e, utility_object.external_source, step_label, utility_object.step_name, 'import_failed.datacycle')
                    raise
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
