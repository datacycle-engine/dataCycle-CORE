# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Frontend feature for the classification suggestion modal on non-image contents (the dialog
    # opened from the content header). It owns nothing but the UI: the requests still go to the
    # content_classifier backend feature (a plugin gem), which is wired in as a :dependencies: entry
    # so the pixie disappears as soon as its backend is missing, disabled or disallowed -- the same
    # composition auto_geocode -> geocode and generated_translation -> translate use.
    class ClassificationPixie < Base
    end
  end
end
