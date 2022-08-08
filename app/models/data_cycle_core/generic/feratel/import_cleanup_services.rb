# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportCleanupServices
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.logging_without_mongo(
            utility_object: utility_object,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.process_content(utility_object, _options)
          items_count = 0
          external_source_id = utility_object.external_source.id
          status = DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Feratel - Status', 'Inaktiv')
          aktiv = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Feratel - Status', 'Aktiv')

          # items without offer
          items = DataCycleCore::Thing
            .where(template_name: 'Service', external_source_id: external_source_id)
            .select { |thing| thing.feratel_status.pluck(:name).include?('Aktiv') }
            .map { |thing| [thing.id, thing.content_content_b.where(relation_a: 'item_offered').size] }
            .select { |_, size| size.zero? }
            .map { |id, _| id }

          DataCycleCore::Thing
            .where(id: items)
            .find_each do |item|
              valid = item.set_data_hash(data_hash: { 'feratel_status' => status })
              items_count += 1 if valid
            end

          # items without active offer
          items = DataCycleCore::Thing
            .where(template_name: 'Service', external_source_id: external_source_id)
            .select { |thing| thing.feratel_status.pluck(:name).include?('Aktiv') }
            .map { |thing| [thing.id, thing.content_content_b.where(relation_a: 'item_offered').pluck(:content_a_id)] }
            .map { |id, offers| [id, DataCycleCore::ClassificationContent.where(classification_id: aktiv, content_data_id: offers).count] }
            .select { |_, size| size.zero? }
            .map { |id, _| id }

          DataCycleCore::Thing
            .where(id: items)
            .find_each do |item|
              valid = item.set_data_hash(data_hash: { 'feratel_status' => status }, partial_update: true)
              items_count += 1 if valid
            end

          items_count
        end
      end
    end
  end
end
