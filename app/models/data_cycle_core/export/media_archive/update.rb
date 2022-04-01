# frozen_string_literal: true

module DataCycleCore
  module Export
    module MediaArchive
      module Update
        def self.process(utility_object:, data:)
          return if data.blank?

          if data.template_name.in?(['Person', 'Organization'])
            DataCycleCore::Export::MediaArchive::Functions.update_person(utility_object: utility_object, data: data, type: :photographers)
            DataCycleCore::Export::MediaArchive::Functions.update_person(utility_object: utility_object, data: data, type: :licenses)
          elsif data.classifications.ids.include?(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Ausgabekanäle', ['Medienarchiv']))
            DataCycleCore::Export::Generic::Functions.update(utility_object: utility_object, data: data)
          else
            DataCycleCore::Export::Generic::Functions.delete(utility_object: utility_object, data: data)
          end
        end

        def self.filter(data, external_system)
          DataCycleCore::Export::Generic::Functions.filter(data: data, external_system: external_system, method_name: name.demodulize.underscore) && (data.classifications.ids.include?(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Ausgabekanäle', ['Medienarchiv'])) || data.external_system_syncs.where(external_system_id: external_system.id).exists?)
        end
      end
    end
  end
end
