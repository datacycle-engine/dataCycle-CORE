# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateHeaderContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:data).hash do
            required(:name) { str? }
            required(:type) { str? & eql?('object') }
            required(:content_type) { str? & included_in?(['embedded', 'entity', 'container']) }
            required(:schema_ancestors) { array? }
            optional(:boost) { int? }
            optional(:features) { hash? }
            required(:properties).hash do
              required(:id) { hash? }
            end
            optional(:api).hash do
              optional(:type) { str? | array? }
            end
          end
        end

        rule(:data) do
          next unless key? && value.present? && value.is_a?(::Hash)

          key.failure(:missing_schema_type_or_ancestors) unless value.key?(:schema_type) || value.key?(:schema_ancestors)
        end
      end
    end
  end
end
