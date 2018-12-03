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

      # keys of the data-hash defined as keys in the template
      def normalize(data, template_hash)
        if data.blank?
          @logger.error 'No data given for normalization.'
          return data
        end
        if template_hash.blank?
          @logger.error 'No data_template given for normalization.'
          return data
        end

        # select_data(data, template_hash)

        ap normalizable_attributes(nil, template_hash.dig('properties'))
        @norm_data # = Normalizer::Object.new(data, template_hash['properties'])
      end

      def normalizable_attributes(root, template_hash)
        template_hash.map { |key, value|
          new_key = nil
          if value.dig('properties').present?
            # included object
            puts "included: #{[root, key].compact.join('/')}"
            new_key = normalizable_attributes([root, key].compact.join('/'), value.dig('properties'))
          elsif value.dig('normalize').present?
            puts "item: #{[root, key].compact.join('/')}"
            new_key = [root, key].compact.join('/')
          end
          new_key
        }.flatten.reject(&:nil?)
      end
    end
  end
end
