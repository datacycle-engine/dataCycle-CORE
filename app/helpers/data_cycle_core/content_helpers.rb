module DataCycleCore
  module ContentHelpers
    def content_type
      metadata['validation']['name']
    end

    def read_write?
      metadata['validation']['permissions']['read_write']
    end

    def title
      raise NotImplementedError
    end

    def desc
      raise NotImplementedError
    end

    def as_json(options = {})
      return super(methods: :is_valid) if options.blank? == false && options['add_validity'] == true
      super
    end

    def get_releasable_hash
      { "release_id" => release_id, "release_comment" => release_comment }
    end

    # def creator
    #   DataCycleCore::User.find(metadata['creator']) if metadata && metadata['creator']
    # end

    def first_available_locale(locale = nil)
      if translated_locales.include?(locale.try(:to_sym)) then locale.try(:to_sym)
      elsif translated_locales.include?(I18n.locale) then I18n.locale
      else translated_locales.first
      end
    end

    def classification_tree_definitions
      metadata['validation']['properties'].select do |key, definition|
        definition['type'] == 'classificationTreeLabel' && definition['editor']
      end.map do |key, definition|
        { key: key }.merge(definition)
      end.sort do |d1, d2|
        d1['editor']['sorting'] <=> d2['editor']['sorting']
      end
    end

    def is_valid
      if try(:validity_period)
        valid_from, valid_to = get_validity_values(validity_period.to_h)
        return Date.today.between?(valid_from.to_date, valid_to.to_date) if valid_from.blank? == false && valid_to.blank? == false
        return Date.today <= valid_to.to_date if valid_to.blank? == false
        return Date.today >= valid_from.to_date if valid_from.blank? == false
      end
      true
    end

    def formatted_validity_period
      if try(:validity_period)
        valid_from, valid_to = get_validity_values(validity_period.to_h)
        { 'date_published' => valid_from.blank? ? '' : valid_from.to_s(:german_date_format), 'expires' => valid_to.blank? || valid_to.to_s(:german_date_format).include?('9999') ? '' : valid_to.to_s(:german_date_format) }
      end
    end
  end
end
