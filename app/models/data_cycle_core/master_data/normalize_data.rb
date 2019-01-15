# frozen_string_literal: true

module DataCycleCore
  module MasterData
    class NormalizeData
      attr_accessor :logger
      attr_accessor :endpoint

      def initialize(logger: nil, host: nil, end_point: nil, **options)
        if logger.blank?
          @logger = DataCycleCore::Generic::Logger::LogFile.new('normalize')
          # @logger = Logger.new('normalize.log', true, false)
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

        normalize_hash = self.class.preprocess_data(template_hash, data)
        return data, [] if normalize_hash.blank?

        report = @endpoint.normalize(id, self.class.reduce_data(normalize_hash.deep_dup), comment)

        updated_hash, diffs = self.class.postprocess_data(data, report, template_hash)
        @logger.info('transforming', diffs) if diffs.present?
        return updated_hash, diffs
      end

      class << self
        def nomalization_transfromation
          { 'name' =>
              [{ 'id' => 'EVENTNAME', 'type' => 'EVENTNAME' },
               { 'id' => 'EVENTPLACE', 'type' => 'PLACE' },
               { 'id' => 'COMPANY', 'type' => 'COMPANY' }],
            'latitude' =>
              [{ 'id' => 'LATITUDE', 'type' => 'LATITUDE' }],
            'longitude' =>
              [{ 'id' => 'LONGITUDE', 'type' => 'LONGITUDE' }],
            'event_period/start_date' =>
              [{ 'id' => 'EVENTSTART', 'type' => 'DATETIME' }],
            'event_period/end_date' =>
              [{ 'id' => 'EVENTEND', 'type' => 'DATETIME' }],
            'honorific_prefix' =>
              [{ 'id' => 'DEGREE', 'type' => 'DEGREE' }],
            'given_name' =>
              [{ 'id' => 'FORENAME', 'type' => 'FORENAME' }],
            'family_name' =>
              [{ 'id' => 'SURNAME', 'type' => 'SURNAME' }],
            'address/street_address' =>
              [{ 'id' => 'STREET', 'type' => 'STREET' }],
            'address/address_locality' =>
              [{ 'id' => 'CITY', 'type' => 'CITY' }],
            'address/postal_code' =>
              [{ 'id' => 'ZIP', 'type' => 'ZIP' }],
            'address/address_country' =>
              [{ 'id' => 'COUNTRY', 'type' => 'COUNTRY' }],
            'contact_info/email' =>
              [{ 'id' => 'EMAIL', 'type' => 'EMAIL' }] }
        end

        def back_transformation
          { 'EVENTNAME' =>  'name',
            'EVENTPLACE' => 'name',
            'LATITUDE' =>   'latitude',
            'LONGITUDE' =>  'longitude',
            'EVENTSTART' => 'event_period/start_date',
            'EVENTEND' =>   'event_period/end_data',
            'DEGREE' =>     'honorific_prefix',
            'FORENAME' =>   'given_name',
            'SURNAME' =>    'family_name',
            'COMPANY' =>    'name',
            'STREET' =>     'address/street_address',
            'CITY' =>       'address/address_locality',
            'ZIP' =>        'address/postal_code',
            'COUNTRY' =>    'address/address_country',
            'EMAIL' =>      'contact_info/email' }
        end

        def preprocess_data(template_hash, data_hash)
          normalize_hash = normalizable_data(nil, template_hash.dig('properties'), data_hash)
          # return normalize_hash, create_transformation(normalize_hash)
          normalize_hash
        end

        def postprocess_data(data, report, template_hash)
          cleaned_report = merge_street_streetnr(report)
          normalized_data = back_transform(cleaned_report.dig('entry', 'fields'))
          # normalized_data = cleaned_report.dig('entry', 'fields').deep_dup
          converted_data = convert_data_types(normalized_data, template_hash)
          updated_data = update_data(data, converted_data)
          diffs = generate_diffs(report)
          return updated_data, diffs
        end

        def generate_diffs(report)
          Normalizer::ActionParser.parse(report)
            .map { |key, value| { back_transformation[key] || key => value } }
            .reduce({}, :merge)
            .reduce({}) { |hash, item| update_path(hash, item[0], item[1]) }
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

        def parse_normalizable_fields(root, template_hash)
          template_hash.map { |key, value|
            if value.dig('properties').present?
              parse_normalizable_fields([root, key].compact.join('/'), value.dig('properties'))
            elsif value.dig('normalize').present?
              { 'id' => [root, key].compact.join('/'), 'type' => value.dig('normalize').upcase }
            end
          }.compact.flatten
        end

        def reduce_data(data_list)
          data_list.map do |item|
            item.update({
              'id' => nomalization_transfromation.dig(item['id']).select { |trans| trans.dig('type') == item['type'] }.first.dig('id'),
              'content' => item.dig('content').to_s
            })
          end
        end

        # maybe support
        #   {
        #    "fieldsProposed" => [],
        #    "entryId" => "32855836",
        #    "taskPhase" => "RESTRUCTURE",
        #    "taskType" => "SPLIT",
        #    "taskId" => "Split_CityZip",
        #    "fieldsBefore" => [{ "type" => "CITY", "content" => "9545 Radenthein", "id" => "CITY" }],
        #    "fieldsAfter" => [
        #      { "type" => "CITY", "content" => "Radenthein", "id" => "CITY" },
        #      { "type" => "ZIP", "content" => "9545", "id" => "ZIP" }
        #     ]
        #   }
        # later

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

        def back_transform(data)
          data.map { |item| item.update('id' => back_transformation[item.dig('id')]) }
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
