# frozen_string_literal: true

# definition ||= nil
json.set! key do
  json.array!(concepts) do |concept|
    json.cache!("#{concept.class}_#{concept.id}_#{@language}_#{concept.updated_at}_#{@mode_parameters.join('_')}", expires_in: 10.minutes) do
      json.id concept.id
      # if definition.present?
      #   json.set! '@type', definition.dig('api', 'type') || 'Enumeration'
      # end
      json.name concept.name(locale: @language) || concept.try(:internal_name)
      json.description concept.description(locale: @language) if concept.description(locale: @language).present?
      json.createdAt concept.created_at
      json.updatedAt concept.updated_at
      deleted_at = concept.try(:deleted_at)
      json.deletedAt deleted_at if deleted_at
      unless @mode_parameters.include?('minimal')
        json.ancestors do
          json.array!(concept.ancestors_with_concept_scheme) do |ancestor|
            json.id ancestor.id
            # if definition.present?
            #   json.set! '@type', definition.dig('api', 'type') || 'Enumeration'
            # end
            json.name ancestor.is_a?(DataCycleCore::ConceptScheme) ? ancestor.name : ancestor.name(locale: @language) || ancestor.try(:internal_name)
            json.createdAt ancestor.created_at
            json.updatedAt ancestor.updated_at
            ancestor_deleted_at = ancestor.try(:deleted_at)
            json.deletedAt ancestor_deleted_at if ancestor_deleted_at
          end
        end
      end
    end
  end
end
