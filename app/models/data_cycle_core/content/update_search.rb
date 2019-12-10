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
        return if search_property_names.blank? || embedded?
        # timestamp = Time.zone.now
        I18n.with_locale(language) do
          search_data = walk_embedded_data(self)
          advanced_search_attributes = walk_advanced(self)

          # TODO: remove hardcoded metadata
          validity_string = get_validity(metadata&.dig('validity_period'))
          boost = schema.dig('boost') || 1.0
          schema_type = schema.dig('schema_type')

          DataCycleCore::Search.where(content_data_id: id, locale: language).first_or_initialize.tap do |s|
            s.full_text = search_data[:full_text]&.unicode_normalize(:nfkc)
            s.created_at = created_at
            s.updated_at = Time.zone.now.to_s(:long_usec)
            s.headline = search_data[:headline]
            s.classification_string = search_data[:classification_string]
            s.data_type = template_name
            s.all_text = search_data[:all_text]&.unicode_normalize(:nfkc)
            s.validity_period = validity_string
            s.boost = boost
            s.schema_type = schema_type
            s.advanced_attributes = advanced_search_attributes
            s.save!
          end
        end
        # ap "### inside update time: #{(Time.zone.now - timestamp)}: #{id}"
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
        if object.embedded?
          string_hash[:classification_string] = ''
        else
          string_hash[:classification_string] = [
            object.display_classification_aliases('tile').pluck(:name).try(:join, ' ').try(:gsub, /[']/, "''"),
            object.display_classification_aliases('tile').pluck(:internal_name).try(:join, ' ').try(:gsub, /[']/, "''")
          ].compact.join(' ')
        end
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

      def walk_advanced(object)
        advanced_data = parse_advanced_data(object)
        object.searchable_embedded_property_names.each do |embedded_name|
          object.try('send', embedded_name)&.each do |embedded_object|
            embedded_advanced_data = walk_advanced(embedded_object)
            advanced_data = append_advanced_data(advanced_data, embedded_advanced_data)
          end
        end
        advanced_data
      end

      def parse_advanced_data(object)
        advanced_data = {}
        # find plain attributes
        object.advanced_search_property_names.each do |property|
          # allow false values
          (advanced_data[property] ||= []) << object.send(property) if object.send(property).present? || object.send(property)&.to_s == 'false'
        end
        # find included properties
        object.advanced_included_search_property_names.each do |property|
          object.properties_for(property).try(:[], 'properties').each do |included_property, included_definition|
            next unless included_definition.dig('advanced_search')
            (advanced_data[[property, included_property].join('.')] ||= []) << object.send(property).send(included_property) if object.send(property).send(included_property).present? || object.send(property).send(included_property)&.to_s == 'false'
          end
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
