# frozen_string_literal: true

module DataCycleCore
  module Content
    module UpdateSearch
      def search_languages(all)
        DataCycleCore::SearchUpdateJob.perform_later(self.class.name, id, all ? nil : I18n.locale.to_s)
      end

      def update_search_languages(all, current_locale)
        if all
          translated_locales.each do |locale|
            update_search(locale)
          end
        else
          update_search(first_available_locale(current_locale))
        end
      end

      def update_search(language)
        return if search_property_names.blank?
        I18n.with_locale(language) do
          search_data = walk_embedded_data(language)
          advanced_search_attributes = walk_advanced
          classification_mapping = walk_classifications
          classification_alias_mapping = classification_mapping.dig(:classification_aliases)
          classification_ancestors_mapping = classification_mapping.dig(:classification_ancestors)

          # TODO: remove hardcoded metadata
          validity_string = get_validity(metadata&.dig('validity_period'))
          boost = schema.dig('boost') || 1.0

          begin
            DataCycleCore::Search.where(content_data_id: id, locale: language).first_or_initialize.tap do |s|
              s.full_text = search_data[:full_text]&.unicode_normalize(:nfkc)
              s.created_at = created_at
              s.updated_at = Time.zone.now
              s.headline = search_data[:headline]
              s.classification_string = search_data[:classification_string]
              s.data_type = template_name
              s.all_text = search_data[:all_text]&.unicode_normalize(:nfkc)
              s.validity_period = validity_string
              s.boost = boost
              s.schema_type = schema_type
              s.advanced_attributes = advanced_search_attributes
              s.classification_aliases_mapping = classification_alias_mapping
              s.classification_ancestors_mapping = classification_ancestors_mapping
              s.self_contained = !embedded?
              s.save!
            end
          rescue ActiveRecord::RecordNotUnique
            retry
          end
        end
      end

      def walk_embedded_data(language)
        string_hash = parse_search_data

        embedded_property_names.each do |embedded_name|
          try('send', embedded_name)&.each do |embedded_object|
            embedded_object.update_search(language)
            embedded_string_hash = embedded_object.walk_embedded_data(language)
            string_hash = append_hash(string_hash, embedded_string_hash)
          end
        end

        string_hash
      end

      def parse_search_data
        string_hash = {}
        string_hash[:full_text] = DataCycleCore::MasterData::DataConverter.string_to_string(search_property_names.map { |item| try(item) }.join(' ').gsub("'", "''"))
        string_hash[:full_text] = '' if string_hash[:full_text].nil?
        string_hash[:headline] = try('title')
        string_hash[:headline] = DataCycleCore::MasterData::DataConverter.string_to_string(string_hash[:headline].gsub("'", "''")) unless string_hash[:headline].nil?
        string_hash[:headline] = '' if string_hash[:headline].nil?

        if embedded? # only headline of main content gets full boost!
          string_hash[:full_text] = [string_hash[:headline], string_hash[:full_text]].join(' ')
          string_hash[:headline] = ''
          string_hash[:classification_string] = ''
        else
          string_hash[:classification_string] = display_classification_aliases(['show', 'show_more']).map { |ca| [ca.name, ca.internal_name] }.flatten.compact.uniq.join(' ').gsub("'", "''").squish
        end

        string_hash[:all_text] = [string_hash[:headline].squish, string_hash[:classification_string], string_hash[:full_text].squish].join(' ')
        string_hash
      end

      def append_hash(hash, add_hash)
        return hash if add_hash.blank?

        hash.each_key do |key|
          hash[key] = [hash[key], add_hash[key]].join(' ')
        end

        hash
      end

      def walk_advanced
        advanced_data = parse_advanced_data

        searchable_embedded_property_names.each do |embedded_name|
          try(embedded_name)&.each do |embedded_object|
            embedded_advanced_data = embedded_object.walk_advanced
            advanced_data = append_advanced_data(advanced_data, embedded_advanced_data)
          end
        end

        advanced_data
      end

      def walk_classifications
        classification_mapping = {
          classification_aliases: classification_aliases.map(&:id),
          classification_ancestors: []
        }
        classification_aliases.each do |c|
          c.ancestors.each do |a|
            classification_mapping[:classification_ancestors] << a.id if a.instance_of?(DataCycleCore::ClassificationAlias)
          end
        end
        classification_mapping[:classification_ancestors].uniq!
        classification_mapping
      end

      def parse_advanced_data
        advanced_data = {}
        # find plain attributes
        advanced_search_property_names.each do |property|
          property_value = try(property)
          (advanced_data[property] ||= []).concat(Array.wrap(property_value.is_a?(ActiveRecord::Relation) ? property_value.pluck(:id) : property_value)) if property_value.present? || property_value&.is_a?(FalseClass)
        end

        # find included properties
        advanced_included_search_property_names.each do |property|
          properties_for(property).try(:[], 'properties').each do |included_property, included_definition|
            next unless included_definition.dig('advanced_search')

            value = try(property).try(included_property)
            (advanced_data[[property, included_property].join('.')] ||= []) << value if value.present? || value.is_a?(FalseClass)
          end
        end

        # find classification properties
        advanced_classification_property_names.each do |property|
          ids = []
          try(property)&.classification_aliases&.each do |c|
            c.ancestors.each do |a|
              ids << a.id if a.instance_of?(DataCycleCore::ClassificationAlias)
            end

            ids << c.id
          end

          (advanced_data[property] ||= []).concat(ids) if ids.present?
        end

        advanced_data
      end

      def append_advanced_data(hash, add_hash)
        return hash if add_hash.blank?

        (hash.keys + add_hash.keys).uniq.each do |key|
          next if add_hash.dig(key).blank?
          hash[key] = (hash[key] || []) + add_hash[key]
          hash[key].uniq!
        end

        hash
      end
    end
  end
end
