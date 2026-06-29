# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Regression test for serialized objects whose class name ends in "s".
  #
  # `resolve_params` used to constantize the serialized `class` via
  # `value['class'].classify.safe_constantize`. `String#classify` singularizes
  # the last segment, so e.g. "DataCycleCore::Thing::Preis" became
  # "DataCycleCore::Thing::Prei" -> `safe_constantize` returned nil. The hash
  # then fell through to the generic branch and stayed a
  # HashWithIndifferentAccess instead of being resolved to the content
  # instance. `remote_render` (embedded viewers) then blew up with
  # `NoMethodError: undefined method 'schema' for an instance of
  # ActiveSupport::HashWithIndifferentAccess`.
  #
  # `class` is always serialized from a real, fully-qualified Ruby class name
  # (see ApplicationHelper#to_query_params), so it must be constantized
  # directly, without `classify`.
  class ParamsResolverTest < DataCycleCore::TestCases::ActiveSupportTestCase
    class FakeController < ActionController::API
      include DataCycleCore::ParamsResolver
    end

    before(:all) do
      @content = create_content('Preis', { name: 'Test Preis' })
    end

    setup do
      @controller = FakeController.new
    end

    test 'resolves a persisted content whose class name ends in "s" to the model instance' do
      resolved = @controller.resolve_params(
        'object' => { 'id' => @content.id, 'class' => 'DataCycleCore::Thing::Preis' }
      )

      assert_instance_of DataCycleCore::Thing::Preis, resolved[:object]
      assert_equal @content.id, resolved[:object].id
      assert_not_kind_of ActiveSupport::HashWithIndifferentAccess, resolved[:object]
      assert_respond_to resolved[:object], :schema # the call that used to raise in the embedded viewer
    end

    test 'resolves a new content (attributes branch) whose class name ends in "s" to the model instance' do
      resolved = @controller.resolve_params(
        'object' => { 'class' => 'DataCycleCore::Thing::Preis', 'attributes' => { 'template_name' => 'Preis' } }
      )

      assert_instance_of DataCycleCore::Thing::Preis, resolved[:object]
      assert_equal 'Preis', resolved[:object].template_name
    end
  end
end
