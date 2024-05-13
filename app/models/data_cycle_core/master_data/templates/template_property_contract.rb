# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplatePropertyContract < DataCycleCore::MasterData::Contracts::GeneralContract
        attr_accessor :property_name

        ALLOWED_OVERLAY_TYPES = ['string', 'text', 'number', 'boolean',
                                 'datetime', 'date', 'geographic', 'slug',
                                 'embedded', 'linked', 'classification',
                                 'schedule', 'opening_time'].freeze

        schema do
          optional(:label) { str? }
          required(:type) do
            str? & included_in?(
              ['key', 'string', 'text', 'number', 'boolean',
               'datetime', 'date', 'geographic', 'slug',
               'object', 'embedded', 'linked', 'classification',
               'asset', 'schedule', 'opening_time',
               'timeseries', 'collection']
            )
          end
          optional(:storage_location) do
            str? & included_in?(['column', 'value', 'translated_value', 'classification'])
          end
          optional(:template_name) { str? | (array? & each { str? }) }
          optional(:validations) { hash? }
          optional(:ui) { hash? }
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
            str? & included_in?(
              ['asset', 'audio', 'image', 'video', 'pdf', 'data_cycle_file', 'srt_file']
            )
          end

          optional(:default_value) do
            str? | number? | (hash? & hash do
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
            bool? | (str? & included_in?(TemplateTransformer::VISIBILITIES.keys)) | (array? & array { included_in?(TemplateTransformer::VISIBILITIES.keys) })
          end
        end

        rule(:type) do
          case value
          when 'object'
            key.failure(:invalid_object) unless values.dig(:properties).present? && ['value', 'translated_value'].include?(values.dig(:storage_location))
          when 'embedded'
            key.failure(:invalid_embedded) unless values.dig(:template_name).present? || values.dig(:stored_filter).present?
          when 'linked'
            key.failure(:invalid_linked) unless values.dig(:template_name).present? || values.dig(:stored_filter).present? || values.dig(:inverse_of).present?
          when 'classification'
            key.failure(:invalid_classification) if values.dig(:tree_label).blank? && values.dig(:universal) != true
          when 'asset'
            key.failure(:invalid_asset) if values.dig(:asset_type).blank?
          end
        end

        rule(:default_value) do
          next unless key? && value.present? && value.is_a?(::Hash)

          key.failure(:invalid_default_value) unless DataCycleCore::ModuleService.load_module(value[:module].classify, 'Utility::DefaultValue').respond_to?(value[:method])
        rescue NameError
          key.failure(:invalid_default_value)
        end

        rule(:compute) do
          next unless key? && value.present?

          key.failure(:invalid_computed) unless DataCycleCore::ModuleService.load_module(value[:module].classify, 'Utility::Compute').respond_to?(value[:method])
        rescue NameError
          key.failure(:invalid_computed)
        end

        rule(:virtual) do
          next unless key? && value.present?

          key.failure(:invalid_virtual) unless DataCycleCore::ModuleService.load_module(value[:module].classify, 'Utility::Virtual').respond_to?(value[:method])
        rescue NameError
          key.failure(:invalid_virtual)
        end

        rule(:content_score) do
          next unless key? && value.present?

          key.failure(:invalid_content_score) unless DataCycleCore::ModuleService.load_module(value[:module].classify, 'Utility::ContentScore').respond_to?(value[:method])
        rescue NameError
          key.failure(:invalid_content_score)
        end

        rule(:properties) do
          key.failure(:invalid_object) if key? && !(values.dig(:type) == 'object' && ['value', 'translated_value'].include?(values.dig(:storage_location)))
        end

        rule(:storage_location) do
          key.failure(:invalid_column) if key? && value == 'column' && ['external_key', 'slug', 'location', 'line', 'geom'].exclude?(property_name.to_s)
        end

        rule(:overlay, :type) do
          key.failure(:invalid_overlay_type) if key? && ALLOWED_OVERLAY_TYPES.exclude?(values[:type])
        end
      end
    end
  end
end
