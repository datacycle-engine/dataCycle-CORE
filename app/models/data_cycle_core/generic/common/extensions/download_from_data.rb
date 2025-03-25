# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Extensions
        module DownloadFromData
          def create_post_unwind_match_stage(path:, source_filter_stage:)
            source_filter_stage
              .deep_dup
              .deep_stringify_keys
              .deep_reject { |k, _| !k.start_with?('$') && k.exclude?(path) }
              .deep_transform_keys { |k| k.gsub(path, 'data') }
          end

          def load_data_from_mongo(options:, locale:, source_filter:, **_keyword_args)
            raise ArgumentError, "missing read_type for #{options.dig(:download, :name)}" if options.dig(:download, :read_type).nil?
            read_type = Mongoid::PersistenceContext.new(
              DataCycleCore::Generic::Collection2, collection: options[:download][:read_type]
            )

            pipelines = create_aggregate_pipeline(options:, locale:, source_filter:)

            DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
              mongo.collection.aggregate(
                pipelines, allow_disk_use: true
              ).to_a
            end
          end

          def data_id(data_id_transformation, data)
            return data['id'].to_s if data_id_transformation.blank?

            transform_data_id_hash(data_id_transformation, data)
          end

          def cleanup_data(cleanup_data_config, data)
            return data if cleanup_data_config.blank? || cleanup_data_config[:module].blank? || cleanup_data_config[:method].blank?

            cleanup_data_config[:module].safe_constantize.public_send(cleanup_data_config[:method], data)
          end

          def id_md5_transformation(data)
            Digest::MD5.hexdigest(data['id'])
          end

          def id_sha1_transformation(data)
            Digest::SHA1.hexdigest(data['id'])
          end

          def data_name(data)
            data['name']
          end

          private

          def transform_data_id_hash(transformation, data)
            case transformation
            when Hash
              transformation[:module]
                .safe_constantize
                .public_send(transformation[:method], data)
            when String
              # binding.pry
              "Digest::#{transformation.classify}".safe_constantize&.hexdigest(data['id'])

            end
          end
        end
      end
    end
  end
end
