# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Toubiz
      module ImportTourRelations
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options.merge({ iterator_type: :aggregate })
          )
        end

        def self.load_contents(mongo_item, locale, _source_filter)
          mongo_item.collection.aggregate(
            [
              {
                '$match': { "dump.#{locale}.tourStageRelations.parent.id": { '$exists': true } }
              }, {
                '$project': {
                  'child_id': "$dump.#{locale}.id",
                  'parent_id': "$dump.#{locale}.tourStageRelations.parent.id"
                }
              }, {
                '$group': {
                  _id: '$parent_id',
                  'parent_id': { '$first': '$parent_id' },
                  'child_ids': { '$addToSet': '$child_id' }
                }
              }, {
                '$addFields': {
                  "dump.#{locale}.id": '$parent_id',
                  "dump.#{locale}.child_ids": '$child_ids'
                }
              }
            ]
          )
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:) # rubocop:disable Lint/UnusedMethodArgument
          I18n.with_locale(locale) do
            item = DataCycleCore::Thing.find_by(
              external_source_id: utility_object.external_source.id,
              external_key: raw_data.dig('id')
            )

            ids = DataCycleCore::Thing.where(
              external_source_id: utility_object.external_source.id,
              external_key: raw_data.dig('child_ids')
            ).ids
            update_hash = { 'contains_place' => ids }
            item.set_data_hash(partial_update: true, prevent_history: false, data_hash: update_hash) if update_hash.present?
          end
        end
      end
    end
  end
end
