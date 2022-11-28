# frozen_string_literal: true

module DataCycleCore
  module MasterData
    class NormalizeData
      attr_accessor :logger
      attr_accessor :endpoint

      def initialize(logger: nil, host: nil, end_point: nil, **options)
        if logger.blank?
          @logger = DataCycleCore::Generic::Logger::LogFile.new('normalize')
        else
          @logger = logger
        end

        @endpoint = DataCycleCore::MasterData::Normalizer::Endpoint.new(host: host, end_point: end_point, **options)
      end

      def normalize(data, template_hash, **options)
        if data.blank?
          @logger.error(nil, nil, nil, 'No data given for normalization.')
          return data, {}
        end
        if template_hash.blank?
          @logger.error(nil, nil, nil, 'No data_template given for normalization.')
          return data, {}
        end

        id = options&.dig(:id)
        comment = options&.dig(:comment)
        @logger.info('processing  ', id)

        normalize_hash, transformation_hash = self.class.preprocess_data(template_hash, data)
        return data, [] if normalize_hash.blank?

        report = @endpoint.normalize(id, normalize_hash, comment)

        updated_hash, diffs = self.class.postprocess_data(data, transformation_hash, report, template_hash)
        @logger.info('transforming', diffs) if diffs.present?
        return updated_hash, diffs
      end

      class << self
        def preprocess_data(template_hash, data_hash)
          normalize_hash = normalizable_data(nil, template_hash.dig('properties'), data_hash)
          split_normalize_hash(normalize_hash)
        end

        def postprocess_data(data, transformation, report, template_hash)
          cleaned_report = merge_street_streetnr(report)
          normalized_data = back_transform(cleaned_report.dig('entry', 'fields'), transformation)
          converted_data = convert_data_types(normalized_data, template_hash)
          updated_data = update_data(data, converted_data)
          diffs = generate_diffs(report, transformation)
          return updated_data, diffs
        end

        def split_normalize_hash(normalized_hash)
          [
            normalized_hash.map { |item| item.except('data_hash_path') },
            normalized_hash.map { |item| item.except('content') }
          ]
        end

        def generate_diffs(report, transformation)
          Normalizer::ActionParser.parse(report)
            .map { |key, value| { transformation.select { |entry| entry['id'] == key }&.first&.dig('data_hash_path') || key => value } }
            .reduce({}, :merge)
            .reduce({}) { |hash, item| update_path(hash, item[0], item[1]) }
        end

        def normalizable_data(root, template_hash, data_hash)
          template_hash.map { |key, value|
            if value.dig('properties').present?
              normalizable_data([root, key].compact.join('/'), value.dig('properties'), data_hash&.dig(key))
            elsif value.dig('normalize').present?
              { 'data_hash_path' => [root, key].compact.join('/'), 'id' => value.dig('normalize', 'id').upcase, 'type' => value.dig('normalize', 'type').upcase, 'content' => data_hash&.dig(key) }
            end
          }.compact.flatten
        end

        def parse_normalizable_fields(root, template_hash)
          template_hash.map { |key, value|
            if value.dig('properties').present?
              parse_normalizable_fields([root, key].compact.join('/'), value.dig('properties'))
            elsif value.dig('normalize').present?
              { 'id' => [root, key].compact.join('/'), 'type' => value.dig('normalize').upcase }
            end
          }.compact.flatten
        end

        def merge_street_streetnr(report)
          fields_list = report&.dig('entry', 'fields')
          return report if fields_list.blank?
          types = fields_list.map { |item| item['type'] }.uniq
          return report unless types.include?('STREET') && types.include?('STREETNR')

          index_street_nr = fields_list.find_index { |item| item['type'] == 'STREETNR' }
          street_nr = fields_list[index_street_nr]['content']
          report['entry']['fields'] = fields_list.map { |item|
            if item['type'] == 'STREET'
              item['content'] += ' ' + street_nr
              item
            elsif item['type'] == 'STREETNR'
              nil
            else
              item
            end
          }.compact

          action_list = report.dig('actionList')
          action_index = action_list.find_index { |item| item['taskType'] == 'SPLIT' && item['taskId'] == 'Split_StreetStreetnr' }
          action_entry = action_list[action_index]
          new_name = fields_list[fields_list.find_index { |item| item['type'] == 'STREET' }]['content']
          old_name = action_entry['fieldsBefore'].first&.dig('content')

          if new_name == old_name
            action_list.delete_at(action_index)
          else
            field_entry = action_entry['fieldsAfter'].find { |item| item['type'] == 'STREET' }
            field_entry['content'] = new_name
            action_entry['fieldsAfter'] = [field_entry]
            action_entry['taskType'] = 'ALTER'
            action_list[action_index] = action_entry
          end
          report['actionList'] = action_list

          report
        end

        def back_transform(data, transformation)
          data.map { |item| item.update('id' => transformation.detect { |entry| item['id'] == entry['id'] }&.dig('data_hash_path')) }
        end

        def convert_data_types(data, template)
          data.map do |item|
            data_type = get_type_from_path(item['id'], template)
            item['content'] = DataCycleCore::MasterData::DataConverter.convert_to_type(data_type, item['content']) if data_type.present?
            item
          end
        end

        def get_type_from_path(path, template)
          return if path.blank?
          template.dig(*(['properties'] * path.split('/').size).zip(path.split('/')).flatten.compact + ['type'])
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
