# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class ApiContract < Dry::Validation::Contract
        config.validate_keys = true

        UUID_OR_STRING_OF_UUIDS_REGEX = /^(\s*[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}\s*)?(,(\s*[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}\s*))*$/i.freeze

        SORTING_VALIDATION = Dry::Types['string'].constructor do |input|
          next input unless input&.starts_with?('random')

          _key, value = DataCycleCore::ApiService.order_key_with_value(input)

          next unless value.nil? || value.between?(-1, 1)

          input
        end

        BASE = Dry::Schema.Params do
          optional(:format).value(:symbol)
          optional(:controller).filled(:string)
          optional(:action).filled(:string)
          optional(:api_subversion).filled(:string)
          optional(:token).filled(:string)
          optional(:id).filled(:string)
          optional(:timeseries).filled(:string)
        end

        CONTENT = Dry::Schema.Params do
          optional(:uuid).filled(:array)
          optional(:uuids).filled(:string)
          optional(:content_id) { str? | array? }
        end

        CLASSIFICATIONS = Dry::Schema.Params do
          optional(:classification_id).filled(:string)
        end

        BASE_JSON_API = Dry::Schema.Params do
          optional(:language).filled(:string)
          optional(:sort).filled(SORTING_VALIDATION)
          optional(:fields).filled(:string)
          optional(:include).filled(:string)
          optional(:classification_trees) { str? | array? }
        end

        WATCHLIST = Dry::Schema.Params do
          optional(:sl).filled(:string)
          optional(:user_email).filled(:string)
          optional(:thing_id).filled(:string)
        end

        PAGE = Dry::Schema.Params do
          optional(:size).value(:integer, gteq?: 1)
          optional(:number).value(:integer, gteq?: 1)
          optional(:limit).value(:integer, gteq?: 1)
          optional(:offset).value(:integer, gteq?: 0)
        end

        SECTION = Dry::Schema.Params do
          optional(:'@graph').value(:integer, included_in?: [0, 1])
          optional(:'@context').value(:integer, included_in?: [0, 1])
          optional(:meta).value(:integer, included_in?: [0, 1])
          optional(:links).value(:integer, included_in?: [0, 1])
        end

        CLASSIFICATIONS_FILTER = Dry::Schema.Params do
          optional(:withSubtree).value(:array, min_size?: 1).each(:str?, format?: UUID_OR_STRING_OF_UUIDS_REGEX)
          optional(:withoutSubtree).value(:array, min_size?: 1).each(:str?, format?: UUID_OR_STRING_OF_UUIDS_REGEX)
        end

        GEO_FILTER = Dry::Schema.Params do
          optional(:box).value(:array, min_size?: 4)
          optional(:perimeter).value(:array, min_size?: 3)
          optional(:shapes).value(:array, min_size?: 1)
        end

        TIME_FILTER = Dry::Schema.Params do
          optional(:in).hash do
            optional(:min).filled(:string)
            optional(:max).filled(:string)
          end
        end

        ATTRIBUTE_FILTER = Dry::Schema.Params do
          optional(:in).hash do
            optional(:min).filled { str? | int? | float? }
            optional(:max).filled { str? | int? | float? }
            optional(:equals).filled { str? | int? | float? }
            optional(:like).filled { str? }
            optional(:bool).filled { bool? }
          end
          optional(:notIn).hash do
            optional(:min).filled { str? | int? | float? }
            optional(:max).filled { str? | int? | float? }
            optional(:equals).filled { str? | int? | float? }
            optional(:like).filled { str? }
            optional(:bool).filled { bool? }
          end
        end

        FILTER = Dry::Schema.Params do
          optional(:contentId).hash do
            optional(:in).filled(:array)
            optional(:notIn).filled(:array)
          end
          optional(:filterId).hash do
            optional(:in).filled(:array)
            optional(:notIn).filled(:array)
          end
          optional(:watchListId).hash do
            optional(:in).filled(:array)
            optional(:notIn).filled(:array)
          end
          optional(:search).value(:string)
          optional(:q).value(:string)
          optional(:classifications).hash do
            optional(:in).hash(CLASSIFICATIONS_FILTER)
            optional(:notIn).hash(CLASSIFICATIONS_FILTER)
          end
          optional(:'dc:classification').hash do
            optional(:in).hash(CLASSIFICATIONS_FILTER)
            optional(:notIn).hash(CLASSIFICATIONS_FILTER)
          end
          optional(:geo).hash do
            optional(:in).hash(GEO_FILTER)
            optional(:notIn).hash(GEO_FILTER)
            optional(:withGeometry).filled(:string)
          end
          optional(:creator).hash do
            optional(:in).filled(:array)
            optional(:notIn).filled(:array)
          end
          optional(:attribute).hash do
            optional(:'dct:deleted').hash(ATTRIBUTE_FILTER)
            (DataCycleCore::ApiService::API_SCHEDULE_ATTRIBUTES +
              DataCycleCore::ApiService::API_DATE_RANGE_ATTRIBUTES +
              DataCycleCore::ApiService::API_NUMERIC_ATTRIBUTES +
              DataCycleCore::ApiService.additional_advanced_attribute_keys).each do |a|
              optional(a).hash(ATTRIBUTE_FILTER)
            end
            optional(:slug).hash(ATTRIBUTE_FILTER)
          end
          optional(:schedule).hash(ATTRIBUTE_FILTER)
        end

        params(BASE, BASE_JSON_API, WATCHLIST, CLASSIFICATIONS, CONTENT) do
          optional(:page).hash(PAGE)
          optional(:section).hash(SECTION)
          optional(:filter).hash(FILTER)
          optional(:time).hash(TIME_FILTER)
        end
      end

      class ApiLinkedContract < Dry::Validation::Contract
        config.validate_keys = true

        params(DataCycleCore::MasterData::Contracts::ApiContract::FILTER) do
        end
      end

      class ApiUnionFilterContract < Dry::Validation::Contract
        config.validate_keys = true

        params(DataCycleCore::MasterData::Contracts::ApiContract::FILTER) do
        end
      end
    end
  end
end
