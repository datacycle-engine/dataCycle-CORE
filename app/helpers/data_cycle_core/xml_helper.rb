# frozen_string_literal: true

module DataCycleCore
  module XmlHelper
    def render_partial(template)
      xml_version = @xml_version || 1
      "data_cycle_core/xml/v#{xml_version}/xml_base/#{template}"
    end

    def xml_attribute(key:, definition:, value:, parameters: {}, content: nil, scope: :xml)
      return if definition['type'] == 'classification' && !visible_classification_tree?(definition['tree_label'], scope.to_s)

      xml_version = @xml_version || 1
      partials = [
        key.underscore.to_s,
        "#{definition['type'].underscore}_#{definition.try(:[], 'xml').try(:[], 'partial').try(:underscore)}",
        "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
        definition['type'].underscore.to_s,
        'default'
      ].reject(&:blank?)

      xml_partials_prefix = "data_cycle_core/xml/v#{xml_version}/xml_base/attributes/"
      return first_existing_xml_partial(partials, xml_partials_prefix), parameters.merge({ key:, definition:, value:, content:, cache: true })
    end

    def content_partial(partial, parameters)
      content_parameter = parameters[:content].model_name.element
      partials = [
        "#{content_parameter}_#{parameters[:content].template_name.underscore}_#{partial}",
        "#{content_parameter}_#{partial}",
        "content_#{partial}",
        partial
      ]
      xml_version = @xml_version || 1
      xml_partials_prefix = "data_cycle_core/xml/v#{xml_version}/xml_base/"

      return first_existing_xml_partial(partials, xml_partials_prefix), parameters.merge(cache: true)
    end

    def first_existing_xml_partial(partials, prefix)
      partials.each do |partial|
        next unless lookup_context.exists?(partial, [prefix], true)
        return prefix + partial
      end
    end

    def overwritten_properties(content, overlay_name)
      return [] if overlay_name.blank? || content.send(overlay_name).blank?
      overlay = content.send(overlay_name).first
      overlay.property_names.select { |item| overlay.try(:send, item).present? }.uniq - ['id']
    end

    def normalize_string(data)
      Nokogiri::HTML.fragment(data)&.to_xhtml
    end

    private

    def visible_classification_tree?(tree_label, scopes)
      (Array(DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label)&.visibility) & Array(scopes)).size.positive?
    end
  end
end
