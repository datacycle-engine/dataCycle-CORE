# frozen_string_literal: true

class FixNewThingTemplateColumnsForLegacyTemplates < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    templates = DataCycleCore::ThingTemplate.where(content_type: nil).map do |template|
      api_schema_types = Array.wrap(template.schema&.dig('schema_ancestors') || template.schema&.dig('schema_type'))
        .map { |a| Array.wrap(a) }
        .reduce(&:zip)
        .flatten

      api_schema_types << "dcls:#{template.template_name}"
      api_schema_types.concat(Array.wrap(template.schema.dig('api', 'type'))) if template.schema.dig('api', 'type').present?
      api_schema_types.compact!
      api_schema_types.uniq!

      {
        template_name: template.template_name,
        content_type: template.schema&.dig('content_type') || 'entity',
        api_schema_types: api_schema_types,
        boost: template.schema&.dig('boost')&.to_i || 1
      }
    end

    return if templates.blank?

    ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

    DataCycleCore::ThingTemplate.upsert_all(templates, unique_by: :template_name)
  end

  def down
  end
end
