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

      return unless width&.positive? && height&.positive?

      "aspect-ratio: #{(width / height).to_r.round(2)};"
    end

    def image_thumb_style(content)
      width = content.try(:width)&.to_f
      height = content.try(:height)&.to_f

      return unless width&.positive? && height&.positive?

      if width > height
        "aspect-ratio: #{(width / height).to_r.round(2)}; width: 100%; max-width: #{width}px;"
      else
        "aspect-ratio: #{(width / height).to_r.round(2)}; height: 100%; max-height: #{height}px;"
      end
    end

    def thing_thumbnail_url(content, linked_attribute = nil, keys = ['thumbnail_url'])
      thing_attribute_url(content, linked_attribute, keys)
    end

    def thing_asset_web_url(content, linked_attribute = nil, keys = ['web_url'])
      thing_attribute_url(content, linked_attribute, keys)
    end

    def grouped_related_contents(content)
      sql = <<-SQL.squish
        SELECT things.template_name,
          ct.relation,
          COUNT(things.id)
        FROM things
          JOIN (
            WITH RECURSIVE content_tree(id, relation) AS (
              SELECT content_contents.content_a_id,
                content_contents.relation_a
              FROM content_contents
              WHERE content_contents.content_b_id = ?
              UNION ALL
              SELECT content_contents.content_a_id,
                content_contents.relation_a
              FROM content_contents
                INNER JOIN things ON things.id = content_contents.content_b_id
                INNER JOIN content_tree ON content_tree.id = content_contents.content_b_id
              WHERE things.content_type = 'embedded'
            )
            SELECT DISTINCT id,
              relation
            FROM content_tree
          ) ct(id, relation) ON ct.id = things.id
        WHERE things.content_type != 'embedded'
        GROUP BY things.template_name,
          ct.relation
        ORDER BY things.template_name ASC;
      SQL

      sanitized_sql = ActiveRecord::Base.send(:sanitize_sql_array, [sql, content.id])
      result = ActiveRecord::Base.connection.select_all(sanitized_sql).to_a
      templates = DataCycleCore::ThingTemplate.where(template_name: result.pluck('template_name')).index_by(&:template_name)

      result.group_by { |v| v['template_name'] }.to_h do |template_name, values|
        [
          templates[template_name],
          values.pluck('relation', 'count').to_h
        ]
      end
    end

    private

    def thing_attribute_url(content, linked_attribute, keys)
      things = [content]
      things.unshift(content.try(linked_attribute)) if linked_attribute.present?

      things.compact.each do |c|
        keys.each do |attribute|
          url = c.try("virtual_#{attribute}") || c.try(attribute)
          return url if url.present?
        end
      end
    end
  end
end
