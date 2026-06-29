# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Automatically geocodes content (POIs, gastronomy, ...) based on its address.
    #
    # This feature is similar to the Geocode_functions transformation,
    # but it is applied automatically after the content is saved,
    # rather than as a transformation step.
    # It may in future replace the Geocode_functions transformation; for now, both are available.
    #
    # Enabled per data-definition via the feature configuration. A post-save hook
    # (DataHash::AutoGeocode) detects changes to the address attribute and queues an
    # AutoGeocodeThingJob. The job reuses the existing 'Geocode' feature (Toursprung)
    # to translate the address into coordinates and writes them back.
    #
    # This class only resolves configuration and validates it; the actual behaviour
    # (deciding whether to geocode, performing it, tagging) lives as instance methods on the
    # content itself, mixed in via DataHash::AutoGeocode (see #data_hash_module). That keeps the
    # logic where the data is and avoids passing the content around as an argument.
    #
    # Which templates are auto-geocoded is decided per-template, like :creatable: / :geocode:: a
    # template opts in via its data definition (:features: :auto_geocode: :allowed: true), which the
    # framework merges into Feature::Base#allowed?(content). The global :allowed: defaults to false
    # (opt-in). #allowed? is narrowed below to templates that actually carry the address attribute +
    # geo target, so a template that inherits the opt-in from an ancestor (e.g. any Place subtype
    # inherits Place's) without those properties is simply inert rather than a misconfiguration.
    #
    # The watched address attribute(s) and the geo target default to the geocode feature's
    # :attribute_keys / :target_key ('address' -> 'location', the schema.org postal-address -> geo
    # mapping from datacycle-schema-base's 'postal_address' + 'geo' mixins); setting :attribute_keys /
    # :target_key on :auto_geocode: itself is optional and only needed to override them. latitude/
    # longitude are derived from the resolved point.
    class AutoGeocode < Base
      LATITUDE_KEY = 'latitude'
      LONGITUDE_KEY = 'longitude'
      GEOCODING_TREE = 'Geocoding'
      GEOCODED_ALIAS = 'geocoded'
      # address sub-fields required for a meaningful geocoding request
      REQUIRED_ADDRESS_KEYS = ['street_address', 'postal_code', 'address_locality'].freeze

      class << self
        # post-save hook (and the geocoding behaviour) prepended into the content lifecycle
        def data_hash_module
          DataCycleCore::Feature::DataHash::AutoGeocode
        end

        # property names of the address attribute(s) to watch for changes (the address source)
        def attribute_keys(content = nil)
          geocode_feature = DataCycleCore::Feature['Geocode']

          configuration(content)['attribute_keys'] || geocode_feature&.attribute_keys(content) || []
        end

        # property the resolved geo point is written to (the geo target), from :target_key config
        def target_key(content = nil)
          geocode_feature = DataCycleCore::Feature['Geocode']

          configuration(content)['target_key'] || geocode_feature&.target_key(content)
        end

        # classification ids for the hard-coded Geocoding/geocoded ownership tag. Used by the
        # content to apply, check and drop the tag.
        def geocoded_classification_ids
          DataCycleCore::Concept.for_tree(GEOCODING_TREE).with_internal_name(GEOCODED_ALIAS).pluck(:classification_id)
        end

        # true when the address hash carries enough sub-fields for a meaningful geocoding request
        def sufficient_address?(address)
          REQUIRED_ADDRESS_KEYS.all? { |key| address[key].present? }
        end

        # auto_geocode is allowed for a content only when it both opts in (super: globally enabled +
        # the template's :features: :auto_geocode: :allowed: true, possibly inherited from an
        # ancestor) AND its template actually carries the watched address attribute(s) + geo target.
        #
        # The attribute check makes an inherited opt-in on a non-geocodable template (e.g. a Place
        # subtype without an address) inert instead of an error.
        def allowed?(content = nil)
          return false unless super

          property_names = Array(content.try(:property_names))
          attribute_keys(content).intersect?(property_names) && property_names.include?(target_key(content))
        end
      end
    end
  end
end
