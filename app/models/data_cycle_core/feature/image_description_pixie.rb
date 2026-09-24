# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Frontend feature that fills the text attributes of an image -- ALT text, title, caption -- from
    # the annotation the embedding backend feature (PixieLens) returns. It composes that backend
    # through :dependencies: exactly like AnnotationPixie composes its two, so the pixie is only
    # available where its backend is.
    #
    # Which attribute is filled from which annotation field is per-template configuration: an
    # attribute opts in with its own :features: block, which Feature::Base#configuration merges into
    # the feature config together with the attribute key.
    #
    #   :description:
    #     :features:
    #       :image_description_pixie:
    #         :allowed: true
    #         :source: alt_text     # alt_text | title | captions
    #
    # Like AnnotationPixie the feature has no write path of its own: suggestions are rendered into
    # the ordinary editors and persisted by the regular save.
    class ImageDescriptionPixie < Base
      # annotation fields that carry text; the service keys each of them per locale
      SOURCES = ['alt_text', 'title', 'captions'].freeze

      class << self
        include DataCycleCore::Feature::Concerns::ImageContent

        # @return [Module] text suggestion action, mixed into the contents controller
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::ImageDescriptionPixie
        end

        # @return [Module] route for that action
        def routes_module
          DataCycleCore::Feature::Routes::ImageDescriptionPixie
        end

        # @param content [DataCycleCore::Thing, nil]
        # @param key [String] attribute key
        # @return [String, nil] annotation field this attribute is filled from
        def source_for(content, key)
          return unless includes_attribute_key(content, key)

          source = configuration(content, key)['source']
          source if source?(source)
        end

        # The same check, for a source configured somewhere other than a :features: block: the
        # computed ALT label names its own in :compute: :source: and asks here, so a misspelled one
        # (:source: alttext) is one config error rather than an attribute that stays blank for
        # every image and says nothing about why.
        #
        # @param source [String, nil] annotation field as configured
        # @return [Boolean] whether it is one this feature reads
        def source?(source)
          SOURCES.include?(source)
        end

        # The opted-in attributes the requester may actually write, i.e. the ones that get a button.
        #
        # @param content [DataCycleCore::Thing, nil]
        # @param user [DataCycleCore::User, nil]
        # @return [Array<String>]
        def editable_attribute_keys(content, user)
          return [] if content.blank? || user.blank?

          allowed_attribute_keys(content).select { |key| attribute_editable?(content, key, user) }
        end

        # One suggestion per opted-in attribute the requester may edit, keyed the way the editors
        # read them. An attribute the service returned nothing for is omitted, so an empty hash is
        # a valid answer.
        #
        # @param data [Hash] the annotations of the image
        # @param content [DataCycleCore::Thing]
        # @param user [DataCycleCore::User, nil]
        # @param locale [String] locale of the editor the wand sits in
        # @return [Hash{String => Hash{String => String}}] attribute key => locale => suggestion
        def suggestions(data, content, user, locale)
          editable_attribute_keys(content, user).index_with { |key|
            suggestion_by_locale(data.to_h[source_for(content, key)], locale)
          }.compact_blank
        end

        # The service keys every text field by locale, and the only one the answer carries is the
        # one it was asked for -- the locale of the editor the wand sits in. That editor writes that
        # translation and nothing else, so a suggestion for another locale would have nowhere to go;
        # filling the others is the inline translation's job.
        #
        # A provider answering with a bare string instead is offered under that same locale, since
        # it is the language the request asked for.
        #
        # @return [Hash{String => String}] locale => suggestion, at most one entry
        def suggestion_by_locale(value, locale)
          return {} if value.blank?
          return { locale => plain_text(value) }.compact_blank unless value.is_a?(::Hash)

          value.slice(locale).transform_values { |text| plain_text(text) }.compact_blank
        end

        # A suggestion is plain text, but it comes from an external service (PixieLens has answered
        # with "<b>Lavendel</b>") and one of the editors it is offered to is a rich text editor,
        # whose import pastes what it is given as HTML. So the markup is removed here, once, rather
        # than trusted anywhere downstream.
        #
        # Nokogiri rather than String#strip_tags, which the app otherwise uses for this: strip_tags
        # leaves an entity standing, so "<p>Berg &amp; Tal</p>" would be offered as
        # "Berg &amp; Tal", while the computed ALT label reads the same annotation field and stores
        # "Berg & Tal" -- one wand and one recompute writing different strings into one attribute.
        #
        # @return [String]
        def plain_text(value)
          Nokogiri::HTML5.fragment(value.to_s).text.strip
        end

        # Whether the computed ALT label (:description_generated:) is generated for this content.
        #
        # A wand is an editor's explicit act and stays available wherever the feature is, but the
        # computed attribute runs on every save of an image and each annotation is a paid request.
        # :generate_for: is where the computed label is configured, and its :external_sources:
        # narrows it to the images of one import -- Canto's (#49225), whose alt texts nobody
        # maintains upstream -- leaving every other image, an editorial upload among them, to the
        # wands:
        #
        #   :image_description_pixie:
        #     :generate_for:
        #       :external_sources:
        #         - canto_dam
        #       :languages: [de, en]
        #
        # Without :external_sources: every image the attribute is on gets a label.
        #
        # @param content [DataCycleCore::Thing, nil]
        # @return [Boolean]
        def generate?(content)
          return false unless allowed?(content)

          sources = Array.wrap(generate_configuration(content)['external_sources']).map { |source| source.to_s.downcase }
          return true if sources.blank?

          system = content.try(:external_source)
          return false if system.blank?

          # by name or identifier: a project's features.yml is written against the names in its
          # external_sources/*.yml, and those files carry both
          sources.intersect?([system.name.to_s.downcase, system.identifier.to_s.downcase])
        end

        # Languages the computed label's annotation is requested in.
        #
        # PixieLens generates a caption, an ALT text and a title per requested language, each its
        # own vision call, so this is what the backfill of an import costs per image. It is the
        # computed label's setting alone: a wand asks for the one locale its editor edits, and the
        # focus point needs no language at all.
        #
        # @param content [DataCycleCore::Thing, nil]
        # @return [Array<String>] the project's main language unless :languages: names others
        def generate_languages(content = nil)
          Array.wrap(generate_configuration(content)['languages'].presence || I18n.default_locale).map(&:to_s)
        end

        private

        # @return [Hash] the :generate_for: block, i.e. everything about the computed label
        def generate_configuration(content)
          configuration(content)['generate_for'] || {}
        end
      end
    end
  end
end
