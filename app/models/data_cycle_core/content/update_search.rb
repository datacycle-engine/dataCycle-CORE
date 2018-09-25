# frozen_string_literal: true

module DataCycleCore
  module Content
    module UpdateSearch
      def search_languages(all)
        if all
          translated_locales.push(I18n.locale).uniq.each do |locale|
            update_search(locale)
          end
        else
          update_search(I18n.locale)
        end
      end

      # def update_search(language)
      #   return if search_property_names.blank?
      #
      #   search_record = DataCycleCore::Search.find_or_initialize_by(
      #     content_data_id: id,
      #     content_data_type: self.class.to_s,
      #     locale: language.to_s
      #   )
      #   search_record.full_text = (search_property_names - ['headline'])&.map { |item| send(item) }&.join(' ')&.gsub(/[']/, "''") || ''
      #   search_record.words = (search_record.full_text + (send('headline')&.gsub(/[']/, "''") || ''))&.gsub(/\s/, ' ') || ''
      #   search_record.headline = self&.headline&.gsub(/[']/, "''") || ''
      #   search_record.data_type = template_name
      #   search_record.classification_string = display_classification_aliases&.pluck(:name)&.try(:join, ' ')&.try(:gsub, /[']/, "''") || ''
      #   search_record.all_text = [search_record.headline, search_record.classification_string, search_record.full_text].join(' ')
      #   validity_data = validity_period if respond_to?(:validity_period)
      #   search_record.validity_period = get_validity(validity_data || nil)
      #   search_record.boost = schema['boost'] || 1.0
      #   search_record.save
      # end

      def update_search(language)
        return if search_property_names.blank?

        full_text = DataCycleCore::MasterData::DataConverter.string_to_string(search_property_names.map { |item| send(item) }.join(' ').gsub(/[']/, "''"))
        full_text = '' if full_text.nil?
        full_text_most = DataCycleCore::MasterData::DataConverter.string_to_string((search_property_names - ['headline']).map { |item| send(item) }.join(' ').gsub(/[']/, "''"))
        full_text_most = '' if full_text_most.nil?
        headline = try('send', 'title')
        headline = DataCycleCore::MasterData::DataConverter.string_to_string(headline.gsub(/[']/, "''")) unless headline.nil?
        headline = '' if headline.nil?
        classification_string = display_classification_aliases.pluck(:name).try(:join, ' ').try(:gsub, /[']/, "''")
        classification_string = '' if classification_string.nil?
        all_text = [headline, classification_string, full_text].join(' ')
        # TODO: remove hardcoded metadata
        validity_hash = metadata.nil? ? nil : metadata['validity_period']
        validity_string = get_validity(validity_hash)
        boost = schema['boost'] || 1.0

        connection = ActiveRecord::Base.connection
        sql_query = <<-EOS
          INSERT INTO searches (id, content_data_id, content_data_type, locale, words, full_text,
            created_at, updated_at, headline, classification_string, data_type, all_text, validity_period,boost)
          VALUES
          ( DEFAULT,
            '#{id}',
            '#{self.class}',
            '#{language}',
            to_tsvector('simple', '#{full_text}'),
            '#{full_text_most}',
            '#{created_at}',
            '#{Time.zone.now.to_s(:long_usec)}',
            '#{headline}',
            '#{classification_string}',
            '#{template_name}',
            '#{all_text}',
            '#{validity_string}',
            #{boost}
          )
          ON CONFLICT (content_data_id, content_data_type, locale)
          WHERE content_data_id = '#{id}' AND content_data_type = '#{self.class}' AND locale = '#{language}'
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
            boost = EXCLUDED.boost;
        EOS
        connection.exec_query(ActiveRecord::Base.send(:sanitize_sql_for_conditions, sql_query))
      end
    end
  end
end
