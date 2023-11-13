# frozen_string_literal: true

Nokogiri::XML::Node.class_eval do
  def to_hash
    attributes_hash = attributes.map { |_, attribute|
      { attribute.name => attribute.value }
    }.reduce({}, &:merge).reject do |_, v|
      v.blank?
    end

    children_hash = children.map { |child|
      { child.name => child.to_hash }
    }.reject { |h|
      h.values.first.blank?
    }.group_by { |h|
      h.keys.first
    }.map { |k, v|
      Hash[k, v.size == 1 ? v.map(&:values).flatten.first : v.map(&:values).flatten]
    }.reduce({}, &:merge)

    if !attributes.empty? && children.empty?
      attributes_hash
    elsif attributes.empty? && !children.empty?
      children_hash
    elsif !attributes.empty? && !children.empty?
      if (attributes_hash.keys & children_hash.keys).empty?
        attributes_hash.merge(children_hash)
      else
        {
          'attributes' => attributes_hash,
          'children' => children_hash
        }
      end
    elsif is_a? Nokogiri::XML::Text
      text.strip
    elsif is_a? Nokogiri::XML::Element
      nil
    else
      raise NotImplementedError
    end
  rescue StandardError => e
    raise e
  end
end
