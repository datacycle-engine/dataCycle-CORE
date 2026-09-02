# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Templates
      # Coverage for the TemplateValidator branch logic - error merging, the
      # translatable / overlay / simple-object validations. The (public) methods are
      # driven directly with crafted template hashes; @templates/@overlay_key are set
      # explicitly so no real template set is needed.
      class TemplateValidatorCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def validator(templates: [])
          DataCycleCore::MasterData::Templates::TemplateValidator.new(templates:)
        end

        test 'merge_errors! prefixes and records each contract error' do
          subject = validator
          error = Object.new
          error.define_singleton_method(:path) { [:name] }
          error.define_singleton_method(:to_s) { 'is invalid' }
          contract = Object.new
          contract.define_singleton_method(:errors) { [error] }

          subject.merge_errors!(contract, ['base', 'Template'])

          assert(subject.errors.any? { |e| e.include?('is invalid') })
        end

        test 'translatable_properties? returns false when no property is translatable' do
          assert_not validator.translatable_properties?({ 'name' => { type: :string, storage_location: 'value' } })
        end

        test 'validate_property_names! flags simple-object sub-keys colliding with root keys' do
          subject = validator
          properties = {
            'obj' => { 'type' => 'object', 'properties' => { 'shared' => {} } },
            'shared' => {}
          }

          subject.validate_property_names!(properties, ['base', 'Template'])

          assert(subject.errors.any? { |e| e.include?('not unique') })
        end

        test 'validate_overlay_properties flags overlay properties missing from the original template' do
          subject = validator
          subject.instance_variable_set(:@overlay_key, 'image')
          subject.instance_variable_set(:@templates, [
                                          { name: 'Original', data: { features: { overlay: { allowed: true } }, properties: { 'image' => { 'template_name' => 'OverlayTpl' }, 'extra' => {} } } }
                                        ])

          subject.validate_overlay_properties({ name: 'OverlayTpl', properties: { 'phantom' => {} } }, ['base', 'OverlayTpl'])

          assert(subject.errors.any? { |e| e.include?('phantom') })
        end

        test 'validate_translatable_embedded! flags a non-translatable embedded without :translated' do
          subject = validator
          subject.instance_variable_set(:@templates, [
                                          { name: 'EmbTpl', data: { properties: { 'x' => { type: :string, storage_location: 'value' } } } }
                                        ])
          template = { data: { properties: { 'emb' => { type: 'embedded', template_name: 'EmbTpl', translated: false } } } }

          subject.validate_translatable_embedded!(template, ['base', 'Template'])

          assert(subject.errors.any? { |e| e.include?('not translatable embedded') })
        end

        test 'validate_limited_by_linked! accepts a computed, virtual or inverse relation' do
          properties = {
            automatic: { type: 'linked', compute: { module: 'Linked', method: 'from_geo_shape' } },
            virtual_rel: { type: 'linked', virtual: { module: 'Linked', method: 'x' } },
            parents: { type: 'linked', link_direction: 'inverse' }
          }
          [:automatic, :virtual_rel, :parents].each do |relation|
            subject = validator
            definition = { type: 'linked', ui: { edit: { options: { limited_by_linked: relation.to_s } } } }

            subject.validate_limited_by_linked!(definition, properties, ['base', 'Template', :data, :properties, :excluded])

            assert_empty subject.errors, "expected #{relation} to be accepted"
          end
        end

        test 'validate_limited_by_linked! flags an editable relation' do
          subject = validator
          properties = { editable: { type: 'linked', template_name: 'POI' } }
          definition = { type: 'linked', ui: { edit: { options: { limited_by_linked: 'editable' } } } }

          subject.validate_limited_by_linked!(definition, properties, ['base', 'Template', :data, :properties, :excluded])

          assert(subject.errors.any? { |e| e.include?('must be a non-editable attribute') })
        end

        test 'validate_limited_by_linked! flags an unknown relation' do
          subject = validator
          definition = { type: 'linked', ui: { edit: { options: { limited_by_linked: ['missing'] } } } }

          subject.validate_limited_by_linked!(definition, {}, ['base', 'Template', :data, :properties, :excluded])

          assert(subject.errors.any? { |e| e.include?("references unknown attribute 'missing'") })
        end

        test 'validate_limited_by_linked! is a no-op without the option' do
          subject = validator

          subject.validate_limited_by_linked!({ type: 'linked' }, {}, ['base', 'Template'])

          assert_empty subject.errors
        end

        test 'validate_schema_types! flags a non-embedded template with schema_ancestors but no schema_types' do
          subject = validator
          data = { content_type: 'entity', schema_ancestors: ['CreativeWork'], properties: { 'name' => {} } }

          subject.validate_schema_types!(data, ['base', 'Template'])

          assert(subject.errors.any? { |e| e.include?('schema_types') && e.include?('meta_data') })
        end

        test 'validate_schema_types! ignores embedded templates' do
          subject = validator
          data = { content_type: 'embedded', schema_ancestors: ['CreativeWork'], properties: { 'name' => {} } }

          subject.validate_schema_types!(data, ['base', 'Template'])

          assert_empty subject.errors
        end

        test 'validate_schema_types! ignores templates without schema_ancestors' do
          subject = validator
          data = { content_type: 'entity', properties: { 'name' => {} } }

          subject.validate_schema_types!(data, ['base', 'Template'])

          assert_empty subject.errors
        end

        test 'validate_schema_types! passes when schema_types is present' do
          subject = validator
          data = { content_type: 'entity', schema_ancestors: ['CreativeWork'], properties: { schema_types: {} } }

          subject.validate_schema_types!(data, ['base', 'Template'])

          assert_empty subject.errors
        end

        test 'validate_locale_inheritance! flags an inheriting template that is not translatable' do
          subject = validator
          data = { properties: { reference: { type: 'linked', features: { locale_inheritance: { allowed: true } } } } }

          subject.validate_locale_inheritance!(data, ['base', 'Template'])

          assert(subject.errors.any? { |e| e.include?('locale_inheritance') && e.include?('translatable') })
        end

        test 'validate_locale_inheritance! passes for a translatable template' do
          subject = validator
          data = {
            features: { translatable: { allowed: true } },
            properties: { reference: { type: 'linked', features: { locale_inheritance: { allowed: true } } } }
          }

          subject.validate_locale_inheritance!(data, ['base', 'Template'])

          assert_empty subject.errors
        end

        test 'validate_locale_inheritance! flags a property that is not linked' do
          subject = validator
          data = {
            features: { translatable: { allowed: true } },
            properties: { reference: { type: 'embedded', features: { locale_inheritance: { allowed: true } } } }
          }

          subject.validate_locale_inheritance!(data, ['base', 'Template'])

          assert(subject.errors.any? { |e| e.include?('reference') && e.include?('linked') })
        end

        test 'validate_locale_inheritance! flags an inverse link' do
          subject = validator
          data = {
            features: { translatable: { allowed: true } },
            properties: { reference: { type: 'linked', link_direction: 'inverse', features: { locale_inheritance: { allowed: true } } } }
          }

          subject.validate_locale_inheritance!(data, ['base', 'Template'])

          assert(subject.errors.any? { |e| e.include?('reference') && e.include?('inverse') })
        end

        test 'validate_locale_inheritance! flags an inheriting embedded template' do
          subject = validator
          data = {
            content_type: 'embedded',
            features: { translatable: { allowed: true } },
            properties: { reference: { type: 'linked', features: { locale_inheritance: { allowed: true } } } }
          }

          subject.validate_locale_inheritance!(data, ['base', 'Template'])

          assert(subject.errors.any? { |e| e.include?('locale_inheritance') && e.include?('embedded') })
        end

        test 'validate_locale_inheritance! ignores templates that inherit no locales' do
          subject = validator
          data = { properties: { reference: { type: 'linked' } } }

          subject.validate_locale_inheritance!(data, ['base', 'Template'])

          assert_empty subject.errors
        end
      end
    end
  end
end
