# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateHeaderContract < DataCycleCore::MasterData::Contracts::GeneralContract
        json do
          required(:data).hash do
            required(:name).value(:string)
            required(:type).value(:string, eql?: 'object')
            required(:content_type).value(:string, included_in?: ['embedded', 'entity', 'container'])
            required(:schema_ancestors).value(:array)
            optional(:boost).value(:integer)
            optional(:features).hash do
              optional(:duplicate_candidate).hash do
                optional(:allowed).value(:bool)
                required(:module) { str? | (array? & each(:string)) }
              end
            end

            required(:properties).hash do
              required(:id).value(:hash)
              required(:external_key).value(:hash)
              required(:dummy).value(:hash)
            end

            optional(:api).hash do
              optional(:type) { str? | (array? & each(:string)) }
            end
          end
        end

        rule(:data) do
          next unless key? && value.present? && value.is_a?(::Hash)

          key.failure(:missing_schema_type_or_ancestors) unless value.key?(:schema_type) ||
                                                                value.key?(:schema_ancestors)
        end

        rule('data.features.duplicate_candidate.module').validate(:duplicate_candidate_module)
      end
    end
  end
end
