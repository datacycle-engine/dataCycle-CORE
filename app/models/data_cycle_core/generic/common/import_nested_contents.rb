# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportNestedContents
        extend ImportFunctionsHelper
        extend Transformations::TransformationUtilities

        def self.import_data(utility_object:, options:)
          # DataCycleCore::Generic::Common::ImportFunctions.import_contents(
          #   utility_object: utility_object,
          #   iterator: method(:load_contents).to_proc,
          #   data_processor: method(:process_content).to_proc,
          #   options: options
          # )
          import(
            utility_object:,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        def self.load_contents(mongo_item:, locale: 'de', source_filter: {}, options: {})
          source_filter = source_filter.merge(options.dig(:import, :source_filter) || {})

          path = ['dump', locale, options.dig(:import, :path)].join('.')
          path_array = path.split('.')
          id_path = [path, options.dig(:import, :id)].join('.')

          aggregation = mongo_item
            .where({ path => { '$ne' => nil } }.merge(source_filter.with_evaluated_values))

          (1..path_array.size)
            .each { |n| aggregation = aggregation.unwind(path_array.take(n).join('.')) }

          project_hash = {
            "dump.#{locale}.id": "$#{id_path}",
            "dump.#{locale}.data": "$#{path}"
          }
          aggregation = aggregation.project(project_hash)

          aggregation = aggregation.group(
            _id: "$dump.#{locale}.id",
            :dump.first => '$dump'
          ).pipeline

          mongo_item.collection.aggregate(aggregation)
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            data_module = options.dig(:import, :data_filter, :module) || options[:transformations]
            data_filter = options.dig(:import, :data_filter, :method)
            return if data_module.blank?
            return if data_filter.present? && !data_module.constantize.method(data_filter).call(raw_data, options.dig(:import, :data_filter))

            transformation = options[:transformations]
              .constantize
              .method(options.dig(:import, :main_content, :transformation))

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

        def self.import(utility_object:, iterator:, data_processor:, options:)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              each_locale(utility_object.locales) do |locale|
                item_count = 0
                step_label = "#{utility_object.external_source.name} #{options.dig(:import, :name)} [#{locale}]"

                begin
                  logging.phase_started(step_label)
                  source_filter = options&.dig(:import, :source_filter) || {}
                  source_filter = I18n.with_locale(locale) { source_filter.with_evaluated_values }
                  source_filter = source_filter.merge({ "dump.#{locale}.deleted_at" => { '$exists' => false }, "dump.#{locale}.archived_at" => { '$exists' => false } })
                  if utility_object.mode == :incremental && utility_object.external_source.last_successful_import.present?
                    source_filter = source_filter.merge({
                      '$or' => [{
                        'updated_at' => { '$gte' => utility_object.external_source.last_successful_import }
                      }, {
                        "dump.#{locale}.updated_at" => { '$gte' => utility_object.external_source.last_successful_import }
                      }]
                    })
                  end

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    times = [Time.current]

                    iterate = iterator.call(mongo_item:, locale:, source_filter:, options:).allow_disk_use(true)
                    iterate.each do |content|
                      break if options[:max_count].present? && item_count >= options[:max_count]
                      item_count += 1
                      next if options[:min_count].present? && item_count < options[:min_count]

                      data_processor.call(
                        utility_object:,
                        raw_data: content.dig('dump', locale, 'data'),
                        locale:,
                        options:
                      )
                    rescue StandardError => e
                      logging.phase_failed(e, utility_object.external_source, step_label)
                    end
                    times << Time.current
                    logging.phase_partial(step_label, item_count, times)
                  end
                ensure
                  logging.phase_finished(step_label, item_count.to_s)
                end
              end
            end
          end
        end
      end
    end
  end
end
