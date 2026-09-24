# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Content::Extensions::ClassifiableSchemes: which concept schemes a user may classify a content on
  # and through which attribute. Core owns this because nothing in it is specific to the
  # content_classifier gem that first needed it -- both Feature::AnnotationPixie and the gem's
  # endpoints answer from here.
  class ClassifiableSchemesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @current_user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
    end

    setup do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'ClassifiableSchemes' })
    end

    # A content classified on the schemes a project marked visible for it, and nothing else.
    def visible_scheme_names
      DataCycleCore::ConceptScheme
        .visible(DataCycleCore::Content::Extensions::ClassifiableSchemes::CLASSIFIABLE_VISIBILITY)
        .order(:name)
        .pluck(:name)
    end

    test 'it answers only visible concept schemes, in name order' do
      names = @content.allowed_properties_for_user(@current_user).pluck('concept_scheme_name')

      assert_predicate names, :present?
      assert_empty names.difference(visible_scheme_names), 'expected no scheme the project did not mark visible'
      assert_equal visible_scheme_names.intersection(names), names, 'expected scheme name order'
    end

    test 'every answer names a scheme and the attribute it is classified through' do
      @content.allowed_properties_for_user(@current_user).each do |property|
        assert_predicate property['concept_scheme_id'], :present?
        assert_predicate property['concept_scheme_name'], :present?
        assert_predicate property['property_key'], :present?
      end
    end

    test 'it answers nothing without a user' do
      assert_empty @content.allowed_properties_for_user(nil)
    end

    # The universal fallback the gem's test stand-in used to miss: a scheme with no dedicated
    # attribute is still classifiable through the shared one.
    test 'a scheme without a dedicated attribute resolves to universal_classifications' do
      properties = @content.allowed_properties_for_user(@current_user)
      universal = DataCycleCore::Content::Extensions::ClassifiableSchemes::UNIVERSAL_PROPERTY_NAME

      assert_includes @content.property_names, universal
      assert_predicate properties.select { |property| property['property_key'] == universal }, :present?,
                       'expected at least one visible scheme to fall back to the shared attribute'
    end

    test 'every answered property_key is one the user may actually write' do
      @content.allowed_properties_for_user(@current_user).each do |property|
        assert DataCycleCore::Feature::Base.attribute_editable?(@content, property['property_key'], @current_user),
               "expected #{property['property_key']} to be editable"
      end
    end

    # A user who may write no classification attribute is offered no scheme, rather than a scheme
    # whose editor then refuses the write.
    test 'a user who may write nothing is offered nothing' do
      @content.define_singleton_method(:classifiable_attribute?) { |_property_name, _user| false }

      assert_empty @content.allowed_properties_for_user(@current_user)
    end

    test 'the resolution is memoized per user' do
      calls = 0
      counting = lambda { |*|
        calls += 1
        []
      }

      @content.stub(:resolve_allowed_properties_for_user, counting) do
        @content.allowed_properties_for_user(@current_user)
        @content.allowed_properties_for_user(@current_user)
      end

      assert_equal 1, calls
    end
  end
end
