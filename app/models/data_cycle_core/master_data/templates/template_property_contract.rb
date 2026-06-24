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
        ALLOWED_STORAGE_LOCATIONS = ['column', 'value', 'translated_value'].freeze
        ALLOWED_ASSET_TYPES = ['asset', 'audio', 'image', 'video', 'pdf', 'data_cycle_file', 'srt_file'].freeze
        BASE_PARAMS = Dry::Schema.JSON do
          optional(:label) do
            str? | hash do
              optional(:key).value(:string)
              optional(:key_prefix).value(:string)
              optional(:key_suffix).value(:string)
            end
          end
          optional(:storage_location).value(:string, included_in?: ALLOWED_STORAGE_LOCATIONS)
          optional(:template_name) { str? | (array? & each(:string)) }
          optional(:validations).value(:hash)
          optional(:ui).value(:hash) do
            optional(:edit).value(:hash) do
              optional(:type).value(:string)
              optional(:options).value(:hash) do
                optional(:data_upload).filled(:bool)
                optional(:shape_from_concept).filled(:bool)
                optional(:sortable).value(:hash) do
                  optional(:proximity_geographic).value(:hash) do
                    required(:attribute).value(:string)
                  end
                end
                optional(:additional_value_paths).value(:hash)
                optional(:additional_values_overlay).array(:string)
              end
            end
          end
          optional(:api).value(:hash)
          optional(:xml).value(:hash)
          optional(:search).value(:bool)
          optional(:advanced_search).value(:bool)
          optional(:overlay).value(:bool)

          # for type object
          optional(:properties).value(:hash)
          # for type embedded and linked
          optional(:stored_filter).value(:array)
          # for type embedded
          optional(:translated).value(:bool)

          # for type linked
          # valid_linked_language?
          optional(:linked_language).value(:string, included_in?: ['all', 'same'])
          optional(:inverse_of).value(:string) # for bidirectional links

          # make sure if link_direction = inverse set api: disabled: true
          # validate_link_direction?
          optional(:link_direction).value(:string, eql?: 'inverse')

          # for type classification
          optional(:tree_label).value(:string) # only members of the specified classification_tree are valid values
          optional(:not_translated).value(:bool) # true -> classification only exists in german
          optional(:external).value(:bool) # true -> only imported can not be manually edited
          optional(:universal).value(:bool) # true -> only for universal_classifications... does not need a tree_label
          optional(:global).value(:bool) # true -> edit is allowed for imported data
          optional(:local).value(:bool) # true -> edit is allowed, attribute will not be importet

          # for type asset
          optional(:asset_type).value(:string, included_in?: ALLOWED_ASSET_TYPES)

          optional(:default_value) do
            bool? | str? | number? | hash do
              required(:module).value(:string)
              required(:method).value(:string)
              optional(:parameters).value(:array)
            end
          end

          optional(:virtual).hash do
            required(:module).value(:string)
            required(:method).value(:string)
            optional(:parameters).value(:array)
          end

          optional(:compute).hash do
            required(:module).value(:string)
            required(:method).value(:string)
            optional(:parameters).value(:array)
            optional(:async).value(:bool)
          end

          optional(:content_score).hash do
            required(:module).value(:string)
            required(:method).value(:string)
            optional(:parameters).value(:array)
            optional(:score_matrix).value(:hash)
          end

          optional(:position).hash do
            optional(:after).value(:string)
            optional(:before).value(:string)
          end

          optional(:visible) do
            bool? |
              (str? & included_in?(Extensions::Visible::VISIBILITIES.keys)) |
              (array? & each(:string, included_in?: Extensions::Visible::VISIBILITIES.keys))
          end

          optional(:priority).filled(:integer, gt?: 0)
        end

        TYPE_PARAMS = Dry::Schema.JSON do
          required(:type).value(:string, included_in?: ALLOWED_PROPERTY_TYPES)
        end

        json(BASE_PARAMS, TYPE_PARAMS)

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
          when 'string'
            key.failure(:missing_storage_location) if values[:storage_location].blank?
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
          key.failure(:invalid_column) if key? && value == 'column' && ['external_key', 'slug'].exclude?(property_name.to_s)
        end

        rule(:overlay, :type) do
          key.failure(:invalid_overlay_type) if key? && (ALLOWED_OVERLAY_TYPES.exclude?(values[:type]) || OVERLAY_KEY_EXCEPTIONS.include?(property_name.to_s))
        end

        rule('ui.edit.options.shape_from_concept') do
          key.failure('shape_from_concept only works with type: Polygon') if key? && values.dig(:ui, :edit, :type) != 'Polygon'
        end

        rule('ui.edit.options.additional_value_paths') do
          next unless key?

          key.failure('is blank') if value.blank?

          value.each do |k, path|
            key.tap { |v| v.path.keys.push(k.to_sym) }.failure('is blank') if path.blank?

            path&.except('geo', 'title')&.each do |k2, p2|
              key.tap { |v| v.path.keys.push(k.to_sym, k2.to_sym) }.failure('is blank') if p2.blank?
            end
          end
        end

        rule('ui.edit.options.additional_value_paths') do
          next unless key? && value.is_a?(Hash) && value.present?

          value.each do |k, path|
            next if path.blank?

            key.tap { |v| v.path.keys.push(k.to_sym, :geo) }.failure('is missing') if path['geo'].blank? && path['title'].present?

            path&.except('geo', 'title')&.each do |k2, p2|
              next if p2.blank?

              key.tap { |v| v.path.keys.push(k.to_sym, k2.to_sym, :geo) }.failure('is missing') if p2['geo'].blank? && p2['title'].present?
            end
          end
        end

        rule('ui.edit.options.additional_value_paths') do
          next unless key? && value.is_a?(Hash) && value.present?

          value.each do |k, path|
            next if path.blank?

            key.tap { |v| v.path.keys.push(k.to_sym, :title) }.failure('is missing') if path['title'].blank? && path['geo'].present?

            path&.except('geo', 'title')&.each do |k2, p2|
              next if p2.blank?

              key.tap { |v| v.path.keys.push(k.to_sym, k2.to_sym, :title) }.failure('is missing') if p2['title'].blank? && p2['geo'].present?
            end
          end
        end

        rule('ui.edit.options.additional_values_overlay').each do
          next unless key?

          key.failure("#{value} is not included in additional_value_paths") unless values.dig(:ui, :edit, :options, :additional_value_paths)&.key?(value)
        end

        rule do
          base.failure(:reserved_property_name) if !_contract.is_a?(ObjectPropertyContract) && RESERVED_PROPERTY_NAMES.include?(property_name.to_s)
        end

        rule do
          base.failure(:data_type_not_string) if property_name.to_s == 'data_type' && values.key?(:default_value) && !values[:default_value].is_a?(String)
        end
      end
    end
  end
end
