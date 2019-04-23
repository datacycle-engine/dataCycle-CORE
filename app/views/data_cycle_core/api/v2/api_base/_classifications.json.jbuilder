# frozen_string_literal: true

# definition ||= nil
json.set! key do
  json.array!(classification_aliases) do |classification_alias|
    json.cache!("#{classification_alias.class}_#{classification_alias.id}_#{@language}_#{classification_alias.updated_at}_#{@mode_parameters.join('_')}", expires_in: 10.minutes) do
      json.id classification_alias.id
      # if definition.present?
      #   json.set! '@type', definition.dig('api', 'type') || 'Enumeration'
      # end
      json.name classification_alias.name(locale: @language) || classification_alias.try(:internal_name)
      json.description classification_alias.description(locale: @language) if classification_alias.description(locale: @language).present?
      json.createdAt classification_alias.created_at
      json.updatedAt classification_alias.updated_at
      json.deletedAt classification_alias.deleted_at if classification_alias.deleted_at
      unless @mode_parameters.include?('minimal')
        json.ancestors do
          json.array!(classification_alias.ancestors) do |ancestor|
            json.id ancestor.id
            # if definition.present?
            #   json.set! '@type', definition.dig('api', 'type') || 'Enumeration'
            # end
            json.name ancestor.is_a?(DataCycleCore::ClassificationTreeLabel) ? ancestor.name : ancestor.name(locale: @language) || ancestor.try(:internal_name)
            json.createdAt ancestor.created_at
            json.updatedAt ancestor.updated_at
            json.deletedAt classification_alias.deleted_at if classification_alias.deleted_at
          end
        end
      end
    end
  end
end
