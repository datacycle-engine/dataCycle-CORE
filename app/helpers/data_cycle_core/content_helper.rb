# frozen_string_literal: true

module DataCycleCore
  module ContentHelper
    def generate_uuid(id, key)
      [
        id.sub(/(.*)-(\w+)$/, '\1'),
        (id.sub(/(.*)-(\w+)$/, '\2').hex ^ Digest::MD5.hexdigest(key)[0..11].hex).to_s(16).rjust(12, '0')
      ].join('-')
    end

    def aspect_ratio(content)
      width = content.try(:width)&.to_f
      height = content.try(:height)&.to_f

      return 16.to_r / 9 unless width&.positive? && height&.positive?

      (width / height).to_r.round(1)
    end

    def thing_thumbnail_url(content, linked_attribute = nil, keys = ['thumbnail_url'])
      thing_attribute_url(content, linked_attribute, keys)
    end

    def thing_asset_web_url(content, linked_attribute = nil, keys = ['web_url'])
      thing_attribute_url(content, linked_attribute, keys)
    end

    def grouped_related_contents(related_objects, content)
      grouped_objects = related_objects.presence&.includes(:content_content_a, :thing_template)&.group_by(&:thing_template)

      return if grouped_objects.blank?

      grouped_objects.transform_values do |objects|
        relation_groups = {}

        objects.each do |object|
          object.content_content_a.each do |cc|
            next if cc.content_b_id != content.id

            relation_groups.key?(cc.relation_a) ? relation_groups[cc.relation_a].push(object) : relation_groups[cc.relation_a] = [object]
          end
        end

        relation_groups
      end
    end

    private

    def thing_attribute_url(content, linked_attribute, keys)
      things = [content]
      things << content.try(linked_attribute) if linked_attribute.present?
      things.compact.each do |c|
        keys.each do |attribute|
          url = c.try("virtual_#{attribute}") || c.try(attribute)
          return url if url.present?
        end
      end
    end
  end
end
