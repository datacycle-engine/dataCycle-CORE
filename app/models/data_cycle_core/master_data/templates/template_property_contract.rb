# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplatePropertyContract < DataCycleCore::MasterData::Contracts::GeneralContract
        attr_accessor :property_name

        ALLOWED_OVERLAY_TYPES = ['string', 'text', 'number', 'boolean',
                                 'datetime', 'date', 'embedded', 'linked',
                                 'classification', 'schedule', 'opening_time', 'object'].freeze
        ALLOWED_PROPERTY_TYPES = ['key', 'string', 'text', 'number', 'boolean',
                                  'datetime', 'date', 'geographic', 'slug',
                                  'object', 'embedded', 'linked', 'classification',
                                  'asset', 'schedule', 'opening_time',
                                  'timeseries', 'collection', 'table', 'oembed'].freeze
        OVERLAY_KEY_EXCEPTIONS = ['overlay', 'id', 'data_type', 'external_key', 'external_source_id'].freeze
        # validation in gitlab has no access to database, so we need to define the reserved property names here
        RESERVED_PROPERTY_NAMES = ['thing_id', 'locale', 'content', 'created_at', 'updated_at', 'metadata', 'template_name', 'external_source_id', 'created_by', 'updated_by', 'deleted_by', 'cache_valid_since', 'deleted_at', 'is_part_of', 'validity_range', 'boost', 'content_type', 'representation_of_id', 'version_name', 'last_updated_locale', 'write_history', 'geom_simple', 'aggregate_type'].freeze
        ALLOWED_STORAGE_LOCATIONS = ['column', 'value', 'translated_value', 'classification'].freeze
        ALLOWED_ASSET_TYPES = ['asset', 'audio', 'image', 'video', 'pdf', 'data_cycle_file', 'srt_file'].freeze
        BASE_PARAMS = Dry::Schema.Params do
          optional(:label) do
            str? | (hash? & hash do
                              optional(:key) { str? }
                              optional(:key_prefix) { str? }
                              optional(:key_suffix) { str? }
                            end)
          end
          optional(:storage_location) do
            str? & included_in?(ALLOWED_STORAGE_LOCATIONS)
          end
          optional(:template_name) { str? | (array? & each { str? }) }
          optional(:validations) { hash? }
          optional(:ui).value(:hash) do
            optional(:edit).value(:hash) do
              optional(:type).value(:string)
              optional(:options).value(:hash) do
                optional(:data_upload).filled(:bool)
                optional(:shape_from_concept).filled(:bool)
              end
            end
          end
          optional(:api) { hash? }
          optional(:xml) { hash? }
          optional(:search) { bool? }
          optional(:advanced_search) { bool? }
          optional(:overlay) { bool? }

          # for type object
          optional(:properties) { hash? }
          # for type embedded and linked
          optional(:stored_filter) { array? }
          # for type embedded
          optional(:translated) { bool? }

          # for type linked
          # valid_linked_language?
          optional(:linked_language) do
            str? & included_in?(
              ['all', 'same']
            )
          end
          optional(:inverse_of) { str? } # for bidirectional links

          # make sure if link_direction = inverse set api: disabled: true
          # validate_link_direction?
          optional(:link_direction) do
            str? & included_in?(
              ['inverse']
            )
          end

          # for type classification
          optional(:tree_label) { str? } # only members of the specified classification_tree are valid values
          optional(:not_translated) { bool? } # true -> classification only exists in german
          optional(:external) { bool? } # true -> only imported can not be manually edited
          optional(:universal) { bool? } # true -> only for universal_classifications... does not need a tree_label
          optional(:global) { bool? } # true -> edit is allowed for imported data
          optional(:local) { bool? } # true -> edit is allowed, attribute will not be importet

          # for type asset
          optional(:asset_type) do
            str? & included_in?(ALLOWED_ASSET_TYPES)
          end

          optional(:default_value) do
            bool? | str? | number? | (hash? & hash do
              required(:module) { str? }
              required(:method) { str? }
              optional(:parameters) { array? }
            end)
          end

          optional(:virtual).hash do
            required(:module) { str? }
            required(:method) { str? }
            optional(:parameters) { array? }
          end

          optional(:compute).hash do
            required(:module) { str? }
            required(:method) { str? }
            optional(:parameters) { array? }
          end

          optional(:content_score).hash do
            required(:module) { str? }
            required(:method) { str? }
            optional(:parameters) { array? }
            optional(:score_matrix) { hash? }
          end

          optional(:position).hash do
            optional(:after) { str? }
            optional(:before) { str? }
          end

          optional(:visible) do
            bool? | (str? & included_in?(Extensions::Visible::VISIBILITIES.keys)) | (array? & array { included_in?(Extensions::Visible::VISIBILITIES.keys) })
          end

          optional(:priority).filled { int? & gt?(0) }
        end

        TYPE_PARAMS = Dry::Schema.Params do
          required(:type) do
            str? & included_in?(ALLOWED_PROPERTY_TYPES)
          end
        end

        schema(BASE_PARAMS, TYPE_PARAMS)

        rule(:type) do
          case value
          when 'object'
            key.failure(:invalid_object) unless values[:properties].present? && ['value', 'translated_value'].include?(values[:storage_location])
          when 'embedded'
            key.failure(:invalid_embedded) unless values[:template_name].present? || values[:stored_filter].present?
          when 'linked'
            key.failure(:invalid_linked) unless values[:template_name].present? || values[:stored_filter].present? || values[:inverse_of].present?
          when 'classification'
            key.failure(:invalid_classification) if values[:tree_label].blank? && values[:universal] != true
          when 'asset'
            key.failure(:invalid_asset) if values[:asset_type].blank?
          end
        end

        rule(:default_value).validate(ruby_module_and_method: 'Utility::DefaultValue')
        rule(:compute).validate(ruby_module_and_method: 'Utility::Compute')
        rule(:virtual).validate(ruby_module_and_method: 'Utility::Virtual')
        rule(:content_score).validate(ruby_module_and_method: 'Utility::ContentScore')
        rule(:validations).validate(:dc_property_validations)

        rule(:properties) do
          key.failure(:invalid_object) if key? && !(values[:type] == 'object' && ['value', 'translated_value'].include?(values[:storage_location]))
        end

        rule(:storage_location) do
          key.failure(:invalid_column) if key? && value == 'column' && ['external_key', 'slug', 'location', 'line', 'geom'].exclude?(property_name.to_s)
        end

        rule(:overlay, :type) do
          key.failure(:invalid_overlay_type) if key? && (ALLOWED_OVERLAY_TYPES.exclude?(values[:type]) || OVERLAY_KEY_EXCEPTIONS.include?(property_name.to_s))
        end

        rule('ui.edit.options.shape_from_concept') do
          key.failure('shape_from_concept only works with type: Polygon') if key? && values.dig(:ui, :edit, :type) != 'Polygon'
        end

        rule do
          base.failure(:reserved_property_name) if !_contract.is_a?(ObjectPropertyContract) && RESERVED_PROPERTY_NAMES.include?(property_name.to_s)
        end
      end
    end
  end
end
