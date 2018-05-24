# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SerializeDeserializeContentTest < ActiveSupport::TestCase
    test 'read untranslatable data from a jsonb field and deserialize to proper objects' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'SimpleJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name,
        metadata: { 'datum' => Time.zone.now.to_s, 'bool' => 'true', 'geo' => 'POINT (10.0 47.0)', 'text' => 'Text' },
        headline: 'Test Data'
      )
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.datum.class.to_s)
      assert_equal('TrueClass', data.bool.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.geo.class.to_s)
    end

    test 'read translatable data from a jsonb field and deserialize to proper objects' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'SimpleJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name,
        content: { 'datum2' => Time.zone.now.to_s, 'bool2' => 'true', 'geo2' => 'POINT (10.0 47.0)', 'text2' => 'test' },
        headline: 'Test Data'
      )
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.datum2.class.to_s)
      assert_equal('TrueClass', data.bool2.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.geo2.class.to_s)
      assert_equal('String', data.text2.class.to_s)
    end

    test 'read untranslatable structured data from a jsonb field and deserialize to proper objects' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'ComplexJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name,
        headline: 'Test Data',
        metadata: { 'data_untrans' => {
          'datum_untrans' => Time.zone.now.to_s,
          'bool_untrans' => 'true',
          'geo_untrans' => 'POINT (10.0 47.0)',
          'text_untrans' => 'Servas'
        } }
      )
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.data_untrans.datum_untrans.class.to_s)
      assert_equal('TrueClass', data.data_untrans.bool_untrans.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.data_untrans.geo_untrans.class.to_s)
      assert_equal('String', data.data_untrans.text_untrans.class.to_s)
    end

    test 'read translatable structured data from a jsonb field and deserialize to proper objects' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'ComplexJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name,
        headline: 'Test Data',
        content: { 'data_trans' => {
          'datum_trans' => Time.zone.now.to_s,
          'bool_trans' => 'true',
          'geo_trans' => 'POINT (10.0 47.0)',
          'text_trans' => 'Servas'
        } }
      )
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.data_trans.datum_trans.class.to_s)
      assert_equal('TrueClass', data.data_trans.bool_trans.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.data_trans.geo_trans.class.to_s)
      assert_equal('String', data.data_trans.text_trans.class.to_s)
    end

    test 'write untranslatable data to a jsonb field' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'SimpleJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name
      )
      data.save
      data_hash = {
        'headline' => 'Test Data',
        'datum' => Time.zone.now,
        'bool' => true,
        'geo' => RGeo::Geographic.spherical_factory(srid: 4326).point(12.3, 40.344),
        'text' => 'Servas'
      }
      data.set_data_hash(data_hash: data_hash)
      data.save

      assert_equal(::String, data.headline.class)
      assert_equal('ActiveSupport::TimeWithZone', data.datum.class.to_s)
      assert_equal('TrueClass', data.bool.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.geo.class.to_s)
    end

    test 'write translatable data to a jsonb field' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'SimpleJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name
      )
      data.save
      data_hash = {
        'headline' => 'Test Data',
        'datum2' => Time.zone.now,
        'bool2' => true,
        'geo2' => RGeo::Geographic.spherical_factory(srid: 4326).point(12.3, 40.344),
        'text2' => 'Servas'
      }
      data.set_data_hash(data_hash: data_hash)
      data.save

      assert_equal(::String, data.headline.class)
      assert_equal('ActiveSupport::TimeWithZone', data.datum2.class.to_s)
      assert_equal('TrueClass', data.bool2.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.geo2.class.to_s)
    end

    test 'write structured data to a jsonb field' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'ComplexJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name
      )
      data.save
      data_hash = {
        'headline' => 'Test Data',
        'data_untrans' => {
          'datum_untrans' => Time.zone.now,
          'bool_untrans' => true,
          'geo_untrans' => RGeo::Geographic.spherical_factory(srid: 4326).point(12.3, 40.344),
          'text_untrans' => 'Servas'
        }
      }
      data.set_data_hash(data_hash: data_hash)
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.data_untrans.datum_untrans.class.to_s)
      assert_equal('TrueClass', data.data_untrans.bool_untrans.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.data_untrans.geo_untrans.class.to_s)
      assert_equal('String', data.data_untrans.text_untrans.class.to_s)
    end

    test 'write structured data to a translateable jsonb field' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'ComplexJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name
      )
      data.save
      data_hash = {
        'headline' => 'Test Data',
        'data_trans' => {
          'datum_trans' => Time.zone.now,
          'bool_trans' => true,
          'geo_trans' => RGeo::Geographic.spherical_factory(srid: 4326).point(12.3, 40.344),
          'text_trans' => 'Servas'
        }
      }
      data.set_data_hash(data_hash: data_hash)
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.data_trans.datum_trans.class.to_s)
      assert_equal('TrueClass', data.data_trans.bool_trans.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.data_trans.geo_trans.class.to_s)
      assert_equal('String', data.data_trans.text_trans.class.to_s)
    end

    test 'serializer/deserializer can handle false, nil, not specified properties properly for bool' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'BoolJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name
      )
      data.save
      data_hash = {
        'headline' => 'Test Data',
        'data' => {
          'flag1' => false,
          'flag2' => nil
        }
      }
      data.set_data_hash(data_hash: data_hash)
      data.save

      assert_equal(false, data.data.flag1)
      assert_nil(data.data.flag2)
      assert_nil(data.data.flag3)

      test_data = DataCycleCore::CreativeWork.find(data.id)
      assert_equal(false, test_data.data.flag1)
      assert_nil(test_data.data.flag2)
      assert_nil(test_data.data.flag3)
    end
  end
end
