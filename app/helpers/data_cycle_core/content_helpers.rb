module DataCycleCore
  module ContentHelpers
    def content_type
      metadata['validation']['name']
    end

    def read_write?
      metadata['validation']['permissions']['read_write']
    end

    def is_valid
      if content_type == 'Bild'
        valid_from = get_data_hash.dig('validity_period').dig('date_published')
        valid_to = get_data_hash.dig('validity_period').dig('expires')
        return Date.today.between?(valid_from.to_date, valid_to.to_date) if (valid_from.blank? == false && valid_to.blank? == false)
        return Date.today <= valid_to.to_date if (valid_to.blank? == false)
        return Date.today >= valid_from.to_date if (valid_from.blank? == false)
      end
      true
    end

    def title
      raise NotImplementedError
    end

    def desc
      raise NotImplementedError
    end

    def get_releasable_hash
      {"release_id" => release_id, "release_comment" => release_comment}
    end

    # def creator
    #   DataCycleCore::User.find(metadata['creator']) if metadata && metadata['creator']
    # end

    def first_available_locale(locale = nil)
      case
        when translated_locales.include?(locale.try(:to_sym)) then locale.try(:to_sym)
        when translated_locales.include?(I18n.locale) then I18n.locale
        else translated_locales.first
      end
    end

    def classification_tree_definitions
      metadata['validation']['properties'].select { |key, definition|
        definition['type'] == 'classificationTreeLabel' && definition['editor']
      }.map { |key, definition|
        {key: key}.merge(definition)
      }.sort { |d1, d2|
        d1['editor']['sorting'] <=> d2['editor']['sorting']
      }
    end
  end
end
