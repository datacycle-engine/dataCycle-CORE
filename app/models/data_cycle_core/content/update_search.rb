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

      def update_search(language)
        return if search_property_names.blank?

        search_record = DataCycleCore::Search.find_or_initialize_by(
          content_data_id: id,
          content_data_type: self.class.to_s,
          locale: language.to_s
        )
        search_record.full_text = (search_property_names - ['headline'])&.map { |item| send(item) }&.join(' ')&.gsub(/[']/, "''") || ''
        search_record.words = search_record.full_text + (send('headline')&.gsub(/[']/, "''") || '')
        search_record.headline = self&.headline&.gsub(/[']/, "''") || ''
        search_record.data_type = template_name
        search_record.classification_string = display_classification_aliases&.pluck(:name)&.try(:join, ' ')&.try(:gsub, /[']/, "''") || ''
        search_record.all_text = [search_record.headline, search_record.classification_string, search_record.full_text].join(' ')
        if respond_to?(:validity_period)
          validity_data = validity_period
          search_record.validity_period = get_validity(validity_data) if validity_data.present?
        end
        search_record.boost = schema['boost'] || 1.0
        search_record.save
      end
    end
  end
end
