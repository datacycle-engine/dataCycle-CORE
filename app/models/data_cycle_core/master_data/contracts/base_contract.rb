# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class BaseContract < Dry::Validation::Contract
        config.validate_keys = true
        config.messages.default_locale = :en
        config.messages.backend = :i18n

        BASE = Dry::Schema.Params do
          optional(:format).value(:symbol)
          optional(:controller).filled(:string)
          optional(:action).filled(:string)
          optional(:api_subversion).filled(:string)
          optional(:token).filled(:string)
          optional(:id).filled(:string)
          optional(:timeseries).filled(:string)
          optional(:dataFormat).filled(:string)
          optional(:search).value(:string)
          optional(:limit).value(:integer)
          optional(:weight).filled(:api_weight_string?)
        end

        EXTERNAL_IDENTITY = Dry::Schema.Params do
          optional(:external_keys).filled(:string)
          optional(:external_source_id).filled(:uuid_or_list_of_uuid?)
        end

        CONTENT = Dry::Schema.Params do
          optional(:uuid).filled(:array)
          optional(:uuids).filled(:string)
          optional(:content_id) { str? | array? }
        end

        CLASSIFICATIONS = Dry::Schema.Params do
          optional(:classification_id).filled(:string)
          optional(:classification_ids).filled(:string)
          optional(:classification_tree_label_id).filled(:uuid_or_list_of_uuid?)
        end

        BASE_JSON_API = Dry::Schema.Params do
          optional(:language).filled(:string)
          optional(:sort).filled(:api_sort_parameter?)
          optional(:fields).filled(:string)
          optional(:include).filled(:string)
          optional(:classification_trees) { (str? & uuid?) | (array? & each(:uuid?)) }
        end

        BASE_MVT_API = Dry::Schema.Params do
          optional(:x).value(:integer)
          optional(:y).value(:integer)
          optional(:z).value(:integer)
          optional(:bbox).value(:bool)
          optional(:layerName).value(:string)
          optional(:clusterLayerName).value(:string)
          optional(:cache).value(:bool)
          optional(:cluster).value(:bool)
          optional(:clusterLines).value(:bool)
          optional(:clusterItems).value(:bool)
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
          optional(:@graph).value(:integer, included_in?: [0, 1])
          optional(:@context).value(:integer, included_in?: [0, 1])
          optional(:meta).value(:integer, included_in?: [0, 1])
          optional(:links).value(:integer, included_in?: [0, 1])
        end

        CLASSIFICATIONS_FILTER = Dry::Schema.Params do
          optional(:withSubtree).value(:array, min_size?: 1).each(:uuid_or_list_of_uuid?)
          optional(:withoutSubtree).value(:array, min_size?: 1).each(:uuid_or_list_of_uuid?)
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

        IN_UUID_OR_NULL_ARRAY_FILTER = Dry::Schema.Params do
          optional(:in).filled(:array).each(:uuid_or_null_string?)
          optional(:notIn).filled(:array).each(:uuid_or_null_string?)
        end

        IN_UUID_ARRAY_FILTER = Dry::Schema.Params do
          optional(:in).filled(:array).each(:uuid?)
          optional(:notIn).filled(:array).each(:uuid?)
        end

        IN_ARRAY_FILTER = Dry::Schema.Params do
          optional(:in).filled(:array)
          optional(:notIn).filled(:array)
        end

        FILTER = Dry::Schema.Params do
          optional(:contentId).hash(IN_ARRAY_FILTER)
          optional(:endpointId).hash(IN_ARRAY_FILTER)
          optional(:filterId).hash(IN_ARRAY_FILTER)
          optional(:watchListId).hash(IN_ARRAY_FILTER)
          optional(:classificationTreeId).hash(IN_ARRAY_FILTER)
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
            optional(:'skos:broader').hash(IN_UUID_OR_NULL_ARRAY_FILTER)
            optional(:'skos:ancestors').hash(IN_UUID_ARRAY_FILTER)
          end
          optional(:schedule).hash(ATTRIBUTE_FILTER)
        end

        TRANSLATE = Dry::Schema.Params do
          optional(:source_locale).filled(:string)
          required(:target_locale).filled(:string)
          required(:text).filled(:string)
        end
      end
    end
  end
end
