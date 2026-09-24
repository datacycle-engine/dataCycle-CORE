# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Test stand-in for the content_classifier backend feature, which really lives in the plugin gem
    # datacycle-feature-content_classifier and is therefore not loaded in data-cycle-core's
    # standalone test environment.
    #
    # The dataPixie frontend features (ClassificationPixie, AnnotationPixie) reach their backend
    # exclusively through Feature::Base#dependencies_*, so declaring the feature is the whole
    # stand-in: the eligibility they ask about is core's own
    # (Content::Extensions::ClassifiableSchemes#allowed_properties_for_user), so the tests pin the
    # behaviour the gem ships rather than a second implementation of it.
    #
    # It has to be defined here rather than inside a test file because routes (config/routes.rb) and
    # the controller mixin (ContentsController) are resolved from Feature[...]&.enabled? at boot.
    #
    # In a host project the real gem defines Datacycle::Feature::ContentClassifier::Base, which
    # DataCycleCore::Feature.[] resolves first, so this class never shadows it.
    class ContentClassifier < Base
    end
  end
end
