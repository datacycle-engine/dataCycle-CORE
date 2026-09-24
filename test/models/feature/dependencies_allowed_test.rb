# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Feature::Base#allowed? folds in #dependencies_allowed? the way #enabled? folds in
  # #dependencies_enabled?, so a feature composed onto a backend (auto_geocode -> geocode,
  # generated_translation -> translate, the pixies -> content_classifier/embedding) does not have to
  # restate it.
  class DependenciesAllowedTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # A feature with a #allowed? of its own that asks for more than a content. Translate is the real
    # one: it wants a target locale, a source locale and a user.
    class NarrowDependency < DataCycleCore::Feature::Base
      class << self
        def feature_key = 'narrow_dependency'
        def enabled? = true
        def dependency_check = :enabled
        def allowed?(_content, _locale, _user) = raise(ArgumentError, 'asked with a content alone')
      end
    end

    class PlainDependency < DataCycleCore::Feature::Base
      class << self
        def feature_key = 'plain_dependency'
        def enabled? = true
      end
    end

    # The composing feature under test: enabled, allowed by its own configuration, and dependent.
    class Dependent < DataCycleCore::Feature::Base
      class << self
        def feature_key = 'dependent'
        def enabled? = true
        def configuration(...) = { 'allowed' => true, dependencies: [@dependency] }
        attr_writer :dependency
      end
    end

    def with_configuration(feature, configuration, &)
      feature.stub(:configuration, ->(*) { configuration }, &)
    end

    def with_dependency(key, feature, &)
      Dependent.dependency = key
      DataCycleCore::Feature.stub(:[], ->(_key) { feature }, &)
    end

    test 'a feature without dependencies is unaffected' do
      with_configuration(PlainDependency, { 'allowed' => true }) do
        assert_predicate PlainDependency, :allowed?
      end

      with_configuration(PlainDependency, { 'allowed' => false }) do
        assert_not PlainDependency.allowed?
      end
    end

    test 'a feature is not allowed while a dependency is not' do
      with_dependency('plain_dependency', PlainDependency) do
        with_configuration(PlainDependency, { 'allowed' => true }) do
          assert_predicate Dependent, :allowed?
        end

        with_configuration(PlainDependency, { 'allowed' => false }) do
          assert_not Dependent.allowed?
        end
      end
    end

    # The regression this guards: generated_translation depends on translate, whose #allowed? takes
    # four arguments, so asking it with a content alone raises instead of answering.
    test 'a dependency declaring :enabled is held to that and never asked for a content' do
      with_dependency('narrow_dependency', NarrowDependency) do
        assert_predicate Dependent, :allowed?
      end
    end

    # Declared rather than read off the arity of #allowed?: Download#allowed?(content,
    # download_scopes = [:content]) has one required parameter today, and making the second one
    # required would otherwise flip every feature depending on download from "checked" to "always
    # allowed" -- no error, no failing test.
    test 'how a dependency may be held is declared, not inferred' do
      assert_equal :enabled, DataCycleCore::Feature::Translate.dependency_check
      assert_equal :allowed, DataCycleCore::Feature::Download.dependency_check
      assert_equal :allowed, DataCycleCore::Feature::AnnotationPixie.dependency_check
    end

    # The real case is a plugin gem that is not installed: auto_geocode declares geocode, whose
    # feature class is Datacycle::Feature::Geocode::Base and not core's -- Feature['Geocode'] then
    # answers nil, which #dependencies_enabled? has already made #enabled? false for.
    test 'a declared dependency no feature answers to is not allowed' do
      with_dependency('nothing_answers_to_this', nil) do
        assert_not Dependent.allowed?
      end
    end

    # What the fold costs the features that already existed. #allowed? is
    # `enabled? && configuration['allowed'] && dependencies_allowed?`, so the new term is last and
    # can only turn a true into a false: a feature changes its verdict only if it declares
    # :allowed: truthy *and* :dependencies: at its own level.
    #
    # Which features declare dependencies at all depends on the configuration loaded -- core's
    # defaults name auto_geocode and generated_translation, test/dummy adds idea_collection -- so
    # what is pinned is the intersection rather than either list. Only the three pixies declare
    # both, and this fails the day an existing feature gains the second half.
    #
    # download is in neither list: its :dependencies: sits inside :downloader:, one level below
    # what #dependencies reads, so as far as Base is concerned it declares none. Naming it at the
    # feature's own level would newly gate every download on serialize's :allowed:, which nothing
    # sets.
    test 'no feature that existed before the fold is gated by it' do
      declared = DataCycleCore.features.select { |_key, config| config.is_a?(::Hash) && config[:dependencies].present? }
      gated = declared.select { |_key, config| config[:allowed] }.keys.map(&:to_s)

      assert_includes declared.keys.map(&:to_s), 'auto_geocode'
      assert_includes declared.keys.map(&:to_s), 'generated_translation'
      assert_equal ['annotation_pixie', 'classification_pixie', 'image_description_pixie'], gated.sort
      assert_empty DataCycleCore::Feature::Download.dependencies
    end
  end
end
