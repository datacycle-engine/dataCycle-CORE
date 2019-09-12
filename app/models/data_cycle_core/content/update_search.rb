# frozen_string_literal: true

module DataCycleCore
  module Content
    module UpdateSearch
      def search_languages(all)
        Delayed::Job.enqueue(DataCycleCore::Jobs::SearchUpdateJob.new(self.class.name, id, all, I18n.locale.to_s)) unless Delayed::Job.exists?(queue: 'search_update', delayed_reference_type: self.class.name, delayed_reference_id: "#{id}_#{all ? 'all' : I18n.locale.to_s}", locked_at: nil)
      end

      def update_search_languages(all, current_locale)
        if all
          translated_locales.push(current_locale).uniq.each do |locale|
            update_search(locale)
          end
        else
          update_search(current_locale)
        end
      end

      def update_search(language)
        return if search_property_names.blank? || content_type == 'embedded'

        I18n.with_locale(language) do
          search_data = walk_embedded_data(self)

          # TODO: remove hardcoded metadata
          validity_string = get_validity(metadata&.dig('validity_period'))
          boost = schema.dig('boost') || 1.0
          schema_type = schema.dig('schema_type')

          connection = ActiveRecord::Base.connection
          sql_query = <<-EOS
            INSERT INTO searches (id, content_data_id, locale, words, full_text,
              created_at, updated_at, headline, classification_string, data_type, all_text, validity_period, boost, schema_type)
            VALUES
            ( DEFAULT,
              '#{id}',
              '#{language}',
              to_tsvector('simple', '#{search_data[:full_text]}'),
              '#{search_data[:full_text]}',
              '#{created_at}',
              '#{Time.zone.now.to_s(:long_usec)}',
              '#{search_data[:headline]}',
              '#{search_data[:classification_string]}',
              '#{template_name}',
              '#{search_data[:all_text]}',
              '#{validity_string}',
              #{boost},
              '#{schema_type}'
            )
            ON CONFLICT (content_data_id, locale)
            WHERE content_data_id = '#{id}' AND locale = '#{language}'
            DO UPDATE SET
              words = EXCLUDED.words,
              full_text = EXCLUDED.full_text,
              created_at = EXCLUDED.created_at,
              updated_at = EXCLUDED.updated_at,
              headline = EXCLUDED.headline,
              classification_string = EXCLUDED.classification_string,
              data_type = EXCLUDED.data_type,
              all_text = EXCLUDED.all_text,
              validity_period = EXCLUDED.validity_period,
              boost = EXCLUDED.boost,
              schema_type = EXCLUDED.schema_type;
          EOS
          connection.exec_query(ActiveRecord::Base.send(:sanitize_sql_for_conditions, sql_query))
        end
      end

      def walk_embedded_data(object)
        string_hash = parse_search_data(object)
        object.embedded_property_names.each do |embedded_name|
          object.try('send', embedded_name)&.each do |embedded_object|
            embedded_string_hash = walk_embedded_data(embedded_object)
            string_hash = append_hash(string_hash, embedded_string_hash)
          end
        end
        string_hash
      end

      def parse_search_data(object)
        string_hash = {}
        string_hash[:full_text] = DataCycleCore::MasterData::DataConverter.string_to_string(object.search_property_names.map { |item| object.send(item) }.join(' ').gsub(/[']/, "''"))
        string_hash[:full_text] = '' if string_hash[:full_text].nil?
        string_hash[:headline] = object.try('send', 'title')
        string_hash[:headline] = DataCycleCore::MasterData::DataConverter.string_to_string(string_hash[:headline].gsub(/[']/, "''")) unless string_hash[:headline].nil?
        string_hash[:headline] = '' if string_hash[:headline].nil?
        string_hash[:classification_string] = [
          object.display_classification_aliases('tile').pluck(:name).try(:join, ' ').try(:gsub, /[']/, "''"),
          object.display_classification_aliases('tile').pluck(:internal_name).try(:join, ' ').try(:gsub, /[']/, "''")
        ].compact.join(' ')
        string_hash[:all_text] = [string_hash[:headline].squish, string_hash[:classification_string].squish, string_hash[:full_text].squish].join(' ')
        string_hash
      end

      def append_hash(hash, add_hash)
        return hash if add_hash.blank?
        hash.each_key do |key|
          hash[key] = [hash[key], add_hash[key]].join(' ')
        end
        hash
      end
    end
  end
end
