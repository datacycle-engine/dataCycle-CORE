# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Update
    # Coverage for the Update::Update entry point and the UpdateData / UpdateTemplate /
    # UpdateSearch strategy mixins. Update::Update runs its whole initialize + Base#update
    # loop over an empty relation (0 iterations, no mutation); the per-item strategy hooks
    # (query / read / modify_content / write) are driven directly on a host object that
    # includes the mixin, with plain content doubles.
    class UpdateStrategiesCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def setup
        @template = DataCycleCore::ThingTemplate.first
      end

      def host_for(mod)
        host = Class.new { include mod }.new
        host.instance_variable_set(:@type, DataCycleCore::Thing)
        host.instance_variable_set(:@template, @template)
        host
      end

      test 'Update::Update initializes, extends a strategy and runs the update loop' do
        updater = nil

        capture_io do
          updater = DataCycleCore::Update::Update.new(
            type: DataCycleCore::Thing.where(id: nil),
            template: @template,
            strategy: DataCycleCore::Update::UpdateData
          )
        end

        assert_kind_of DataCycleCore::Update::Update, updater
      end

      test 'UpdateData query/read/modify_content/write operate on a content item' do
        host = host_for(DataCycleCore::Update::UpdateData)
        host.instance_variable_set(:@transformation, ->(data_hash) { data_hash })

        assert_kind_of ActiveRecord::Relation, host.query

        captured = {}
        content_item = Object.new
        content_item.define_singleton_method(:get_data_hash) { { 'name' => 'x' } }
        content_item.define_singleton_method(:template_name=) { |value| captured[:template_name] = value }
        content_item.define_singleton_method(:save) { captured[:saved] = true }
        content_item.define_singleton_method(:set_data_hash) { |**kwargs| captured[:written] = kwargs }

        assert_equal({ 'name' => 'x' }, host.read(content_item))
        host.modify_content(content_item)
        host.write(content_item, { 'name' => 'x' }, Time.zone.now)

        assert_equal @template.template_name, captured[:template_name]
        assert captured[:saved]
        assert captured[:written][:prevent_history]
      end

      test 'UpdateTemplate query/read/modify_content/write operate on a content item' do
        host = host_for(DataCycleCore::Update::UpdateTemplate)

        assert_kind_of ActiveRecord::Relation, host.query
        assert_empty host.read(nil)
        assert_empty host.write(nil, nil, nil)

        captured = {}
        content_item = Object.new
        content_item.define_singleton_method(:template_name=) { |value| captured[:template_name] = value }
        content_item.define_singleton_method(:available_locales) { [:de] }
        content_item.define_singleton_method(:save) { |**| captured[:saved] = true }

        host.modify_content(content_item)

        assert_equal @template.template_name, captured[:template_name]
        assert captured[:saved]
      end

      test 'UpdateSearch query/read/modify_content/write operate on a content item' do
        host = host_for(DataCycleCore::Update::UpdateSearch)

        assert_kind_of ActiveRecord::Relation, host.query
        assert_empty host.read(nil)
        assert_empty host.write(nil, nil, nil)

        searched = []
        content_item = Object.new
        content_item.define_singleton_method(:translated_locales) { [:de, :en] }
        content_item.define_singleton_method(:update_search) { |lang| searched << lang }

        host.modify_content(content_item)

        assert_equal [:de, :en], searched
      end
    end
  end
end
