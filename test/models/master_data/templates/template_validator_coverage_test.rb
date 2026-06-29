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
      end
    end
  end
end
