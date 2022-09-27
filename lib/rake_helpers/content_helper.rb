# frozen_string_literal: true

class ContentHelper
  class << self
    def find_or_create_content(external_source: nil, external_key: nil, template_name: nil, data: nil)
      content = DataCycleCore::Thing.where(
        template_name: template_name,
        external_source_id: external_source&.id,
        external_key: external_key
      ).first

      unless content
        content = DataCycleCore::Thing.find_by!(template_name: template_name, template: true).dup

        content.template = false
        content.created_at = Time.zone.now
        content.updated_at = content.created_at
        content.created_by = nil
        content.external_source_id = external_source&.id
        content.external_key = external_key
        content.save!(touch: false)

        content.set_data_hash(data_hash: data, new_content: true)
      end

      content
    end
  end
end
