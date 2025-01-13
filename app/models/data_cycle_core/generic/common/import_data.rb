# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportData
        def delete_data(utility_object:, iterator:, data_processor:, options:)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              each_locale(utility_object.locales) do |locale|
                step_label = utility_object.step_label(options.merge({ locales: [locale] }))

                begin
                  logging.phase_started(step_label)
                  source_filter = { "dump.#{locale}.deleted_at" => { '$exists' => true } }

                  source_filter = { "dump.#{locale}.deleted_at" => { '$gte' => utility_object.external_source.last_successful_import } } if utility_object.mode == :incremental && utility_object.external_source.last_successful_import.present?

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    iterate = iterator.call(mongo_item, locale, source_filter)
                    total = iterate.size
                    data = iterate.to_a
                    times = [Time.current]

                    data_processor.call(utility_object: utility_object, raw_data: data, locale: locale, options: options)

                    times << Time.current

                    logging.phase_finished(step_label, total.to_s, times[-1] - times[-2])
                  rescue StandardError => e
                    logging.phase_failed(e, utility_object.external_source, step_label, 'import_failed.datacycle')
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
