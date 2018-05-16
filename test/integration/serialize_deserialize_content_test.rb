require 'test_helper'

module DataCycleCore
  class SerializeDeserializeContentTest < ActiveSupport::TestCase
    test 'read untranslatable data from a jsonb field and deserialize to proper objects' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'SimpleJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name,
        metadata: { datum: Time.zone.now.to_s, bool: 'true', geo: 'POINT (10.0 47.0)' },
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
        content: { datum2: Time.now.to_s, bool2: 'true', geo2: 'POINT (10.0 47.0)' },
        headline: 'Test Data'
      )
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.datum2.class.to_s)
      assert_equal('TrueClass', data.bool2.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.geo2.class.to_s)
    end

    test 'read untranslatable structured data from a jsonb field and deserialize to proper objects' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'ComplexJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name,
        headline: 'Test Data',
        metadata: { data_untrans: { datum_untrans: Time.zone.now.to_s, bool_untrans: 'true', geo_untrans: 'POINT (10.0 47.0)' } }
      )
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.data_untrans.datum_untrans.class.to_s)
      assert_equal('TrueClass', data.data_untrans.bool_untrans.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.data_untrans.geo_untrans.class.to_s)
    end

    test 'read translatable structured data from a jsonb field and deserialize to proper objects' do
      data_template = DataCycleCore::CreativeWork.find_by(template_name: 'ComplexJsonTest', template: true)
      data = DataCycleCore::CreativeWork.new(
        schema: data_template.schema,
        template_name: data_template.template_name,
        headline: 'Test Data',
        content: { data_trans: { datum_trans: Time.zone.now.to_s, bool_trans: 'true', geo_trans: 'POINT (10.0 47.0)' } }
      )
      data.save

      assert_equal('ActiveSupport::TimeWithZone', data.data_trans.datum_trans.class.to_s)
      assert_equal('TrueClass', data.data_trans.bool_trans.class.to_s)
      assert_equal('RGeo::Geographic::SphericalPointImpl', data.data_trans.geo_trans.class.to_s)
    end
  end
end
