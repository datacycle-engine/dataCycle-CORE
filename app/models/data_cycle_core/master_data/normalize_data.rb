# frozen_string_literal: true

module DataCycleCore
  module MasterData
    class NormalizeData
      attr_accessor :logger
      attr_accessor :endpoint

      def initialize(logger: nil, host: nil, end_point: nil, **options)
        if logger.blank?
          @logger = Logger.new(Rails.root.join('log', 'normalize.log'))
        else
          @logger = logger
        end

        @endpoint = DataCycleCore::MasterData::Normalizer::Endpoint.new(host: host, end_point: end_point, **options)
      end

      def normalize(data, template_hash)
        if data.blank?
          @logger.error 'No data given for normalization.'
          return data, {}
        end
        if template_hash.blank?
          @logger.error 'No data_template given for normalization.'
          return data, {}
        end

        normalize_hash, transformation_hash = self.class.preprocess_data(template_hash, data)

        report = @endpoint.normalize(data['id'], self.class.reduce_data(normalize_hash))

        self.class.postprocess_data(data, report, transformation_hash)
      end

      class << self
        def preprocess_data(template_hash, data_hash)
          normalize_hash = normalizable_data(nil, template_hash.dig('properties'), data_hash)
          return normalize_hash, create_transformation(normalize_hash)
        end

        def postprocess_data(data, report, transformation_hash)
          normalized_data = back_transformation(report.dig('entry', 'fields'), transformation_hash)
          updated_data = update_data(data, normalized_data)

          diffs = Normalizer::ActionParser.parse(report)
            .map { |key, value| { transformation_hash[key] || key => value } }
            .reduce({}, :merge)
            .reduce({}) { |hash, item| update_path(hash, item[0], item[1]) }
          return updated_data, diffs
        end

        def normalizable_data(root, template_hash, data_hash)
          template_hash.map { |key, value|
            if value.dig('properties').present?
              normalizable_data([root, key].compact.join('/'), value.dig('properties'), data_hash&.dig(key))
            elsif value.dig('normalize').present?
              { 'id' => [root, key].compact.join('/'), 'type' => value.dig('normalize').upcase, 'content' => data_hash&.dig(key) }
            end
          }.compact.flatten
        end

        def reduce_data(data_list)
          data_list.map { |item| item.update({ 'id' => item['type'] }) }
        end

        def create_transformation(normalize_hash)
          normalize_hash.map { |item|
            { item.dig('type') => item.dig('id') }
          }.reduce({}, :merge)
        end

        def back_transformation(data, transformation)
          data.map { |item| item.update('id' => transformation[item.dig('type')]) }
        end

        def update_data(old_data, update_list)
          new_data = old_data.deep_dup || {}
          update_list.each do |item|
            new_data = update_path(new_data, item.dig('id'), item.dig('content'))
          end
          new_data
        end

        def update_path(hash, path, value)
          return hash if path.blank? || value.blank?
          set_value(hash.deep_dup, path.split('/'), value)
        end

        def set_value(hash, path, value)
          return value if path.blank?
          return hash unless hash.is_a?(::Hash)
          hash[path.first] = set_value(hash[path.first] || {}, path[1..-1], value)
          hash
        end
      end
    end
  end
end
