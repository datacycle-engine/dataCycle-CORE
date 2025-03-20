# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    class ContentTemplateChangeTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @organization_dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Organisation').pluck(:classification_id)
        @organization_st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('Organization').pluck(:classification_id)

        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'test name de' })

        assert_equal @organization_dt, @content.data_type.pluck(:id)
        assert_equal @organization_st, @content.schema_types.pluck(:id)
        assert_equal 1.0, @content.boost
        assert_equal 'entity', @content.content_type
      end

      test 'change template to article' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel').template_thing
        @content.template_name = 'Artikel'
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        assert_equal 100.0, @content.boost
        assert_equal 'entity', @content.content_type
        assert_equal tt.translatable_property_names, @content.translatable_property_names
        assert_equal tt.untranslatable_property_names, @content.untranslatable_property_names

        @content.save!

        assert_equal dt, @content.data_type.pluck(:id)
        assert_equal st, @content.schema_types.pluck(:id)
      end

      test 'change template to article and reload' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel').template_thing
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        @content.update(template_name: 'Artikel')
        @content.reload

        assert_equal 100.0, @content.boost
        assert_equal 'entity', @content.content_type
        assert_equal tt.translatable_property_names, @content.translatable_property_names
        assert_equal tt.untranslatable_property_names, @content.untranslatable_property_names
        assert_equal dt, @content.data_type.pluck(:id)
        assert_equal st, @content.schema_types.pluck(:id)
      end

      test 'change template to embedded Action' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Action').template_thing
        @content.template_name = 'Action'

        assert_equal 1.0, @content.boost
        assert_equal 'embedded', @content.content_type
        assert_equal tt.translatable_property_names, @content.translatable_property_names
        assert_equal tt.untranslatable_property_names, @content.untranslatable_property_names
      end

      test 'change thing_template to Artikel' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel')
        @content.thing_template = tt
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        assert_equal 100.0, @content.boost
        assert_equal 'entity', @content.content_type
        assert_equal tt.template_thing.translatable_property_names, @content.translatable_property_names
        assert_equal tt.template_thing.untranslatable_property_names, @content.untranslatable_property_names

        @content.save!

        assert_equal dt, @content.data_type.pluck(:id)
        assert_equal st, @content.schema_types.pluck(:id)
      end

      test 'change thing_template to Artikel and reload' do
        tt = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel')
        dt = DataCycleCore::Concept.for_tree('Inhaltstypen').with_internal_name('Artikel').pluck(:classification_id)
        st = DataCycleCore::Concept.for_tree('SchemaTypes').with_internal_name('dcls:Artikel').pluck(:classification_id)

        @content.update(thing_template: tt)
        @content.reload

        assert_equal 100.0, @content.boost
        assert_equal 'entity', @content.content_type
        assert_equal tt.template_thing.translatable_property_names, @content.translatable_property_names
        assert_equal tt.template_thing.untranslatable_property_names, @content.untranslatable_property_names
        assert_equal dt, @content.data_type.pluck(:id)
        assert_equal st, @content.schema_types.pluck(:id)
      end
    end
  end
end
