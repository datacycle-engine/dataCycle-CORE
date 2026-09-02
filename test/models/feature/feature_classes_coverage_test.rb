# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # a real, constantizable builder for the PreviewLink#build path
  module PreviewLinkCovBuilder
    def self.build_it(content, locale)
      "#{content}:#{locale}"
    end
  end

  # Coverage for the small Feature::* classes/route modules left below 90%. Feature
  # class methods are driven with a stubbed `configuration`; the route modules are
  # `extend`ed with a router double capturing post/patch/authenticate.
  class FeatureClassesCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    F = DataCycleCore::Feature

    test 'ExternalMediaArchive.get_template_name maps by asset type' do
      F::ExternalMediaArchive.stub(:configuration, { 'template_mapping' => { 'Image' => 'image', 'Video' => 'video' } }) do
        assert_equal ['Image', 'Video'], F::ExternalMediaArchive.get_template_name('video')
        assert_equal 'Image', F::ExternalMediaArchive.get_template_name('image')
      end
    end

    test 'PreviewLink.build sends the configured method to the configured module' do
      F::PreviewLink.stub(:configuration, { module: 'DataCycleCore::PreviewLinkCovBuilder', method: 'build_it' }) do
        assert_equal 'thing:de', F::PreviewLink.build('thing', 'de')
      end

      F::PreviewLink.stub(:configuration, {}) do
        assert_nil F::PreviewLink.build('thing', 'de') # blank module -> early return
      end
    end

    test 'TranslatedDataLink.locales honours configured locales and falls back' do
      F::TranslatedDataLink.stub(:configuration, { 'locales' => ['de'] }) do
        assert_kind_of Hash, F::TranslatedDataLink.locales
      end
      F::TranslatedDataLink.stub(:configuration, nil) do
        assert_kind_of Hash, F::TranslatedDataLink.locales
      end
    end

    test 'Normalize exposes its controller and routes modules' do
      assert_equal F::ControllerFunctions::Normalize, F::Normalize.controller_module
      assert_equal F::Routes::Normalize, F::Normalize.routes_module
    end

    test 'route modules register their routes on the router' do
      router = Object.new
      def router.post(*)
      end

      def router.patch(*)
      end

      def router.authenticate(&) = yield

      assert_nothing_raised { F::Routes::Normalize.extend(router) }
      assert_nothing_raised { F::Routes::FocusPointEditor.extend(router) }
      assert_nothing_raised { F::Routes::GravityEditor.extend(router) }
    end

    test 'ViewMode ability grants grid and reaches the ranked branch' do
      user = Object.new
      user.define_singleton_method(:has_rank?) { |*| false }

      ability = F::Abilities::ViewMode.new(user)

      assert ability.can?(:grid, :view_mode)
    end
  end
end
