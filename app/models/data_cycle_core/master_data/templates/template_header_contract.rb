# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateHeaderContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:data).hash do
            required(:name) { str? }
            required(:type) { str? & eql?('object') }
            required(:schema_type) { str? }
            required(:content_type) { str? & included_in?(['embedded', 'entity', 'container']) }
            optional(:boost) { float? }
            optional(:features) { hash? }
            required(:properties).hash do
              required(:id) { hash? }
            end
            optional(:api).hash do
              optional(:type) { str? | array? }
            end
          end
        end
      end
    end
  end
end
