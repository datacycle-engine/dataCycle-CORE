# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for the GravityEditor feature class methods: the controller/routes
    # module accessors, allowed? (base feature + responding attribute key),
    # user_can_edit? (feature permission combined with user abilities) and
    # transform_gravity! (resolving the gravity option from a concept uri).
    class GravityEditorCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Feature::GravityEditor

      test 'controller_module and routes_module expose the gravity editor modules' do
        assert_equal(DataCycleCore::Feature::ControllerFunctions::GravityEditor, Subject.controller_module)
        assert_equal(DataCycleCore::Feature::Routes::GravityEditor, Subject.routes_module)
      end

      test 'allowed? requires the base feature and a responding attribute key' do
        content = Object.new
        content.define_singleton_method(:gravity_key) { nil }

        result = Subject.stub(:enabled?, true) do
          Subject.stub(:configuration, { 'allowed' => true, 'attribute_keys' => ['gravity_key'] }) do
            Subject.allowed?(content)
          end
        end

        assert(result)
      end

      test 'user_can_edit? combines feature permission with user abilities' do
        content = Object.new
        content.define_singleton_method(:properties_for) { |_key| {} }
        user = Object.new
        user.define_singleton_method(:can?) { |*_args| true }

        result = Subject.stub(:allowed?, true) do
          Subject.stub(:primary_attribute_key, 'gravity_key') do
            Subject.user_can_edit?(content, user)
          end
        end

        assert(result)
      end

      test 'transform_gravity! sets the gravity option from the concept uri' do
        concept = Object.new
        concept.define_singleton_method(:uri) { 'https://schema.org/Thing#center' }
        options = {}

        Subject.stub(:primary_attribute_key, 'gravity_key') do
          DataCycleCore::Concept.stub(:find_by, concept) do
            Subject.transform_gravity!(options, { 'gravity_key' => 'class-id' })
          end
        end

        assert_equal('center', options['gravity'])
      end

      test 'transform_gravity! does nothing when the gravity param is blank' do
        options = {}

        Subject.stub(:primary_attribute_key, 'gravity_key') do
          Subject.transform_gravity!(options, {})
        end

        assert_empty(options)
      end
    end
  end
end
