# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Extensions
        module DownloadFromData
          def load_concepts_from_mongo(lang: 'de')
            raise ArgumentError, 'missing read_type for loading location ranges' if @read_type.nil?
            # subtype = @read_type.chop

            DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
              mongo.collection.aggregate([
                {
                  '$match' => { "dump.#{lang}" => { '$exists' => true } }
                }]).to_a
            end
          end

          def concepts_from_data(*, lang:)
            Enumerator.new do |yielder|
              load_concepts_from_mongo(lang:).each do |type|
                yielder << type
              end
            end
          end
        end
      end
    end
  end
end
