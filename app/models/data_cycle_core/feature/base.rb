# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Base
      attr_reader :content

      delegate :configuration, :enabled?, :feature_key, :feature_path, :dependencies, :dependencies_enabled?, :dependencies_allowed?, :attribute_keys, :available?, :allowed?, :allowed_attribute_keys, :allowed_attribute_key?, :attribute_editable?, :includes_attribute_key, :memoize_key, :primary_attribute_key, to: :class

      def initialize(content: nil)
        @content = content
      end

      class << self
        def enabled?
          @enabled ||= DataCycleCore.features.dig(feature_key.to_sym, :enabled) && dependencies_enabled?
        end

        def feature_key
          name.delete_suffix('::Base').demodulize.underscore
        end

        def feature_path
          name.delete_suffix('::Base').underscore
        end

        def dependencies(content = nil)
          Array.wrap(configuration(content)[:dependencies])
        end

        def dependencies_enabled?(content = nil)
          dependencies(content).all? { |d| DataCycleCore::Feature[d]&.enabled? }
        end

        # One read of #dependencies: it rebuilds #configuration for the content, which walks and
        # hashes the template schema, and asking it twice per #allowed? -- once here and once
        # through #dependencies_enabled? -- is one of the walks per form render this branch is
        # otherwise about removing. #dependency_allowed? holds each dependency to its #enabled?
        # itself, so nothing is lost by not calling that predicate here.
        def dependencies_allowed?(content = nil)
          dependencies(content).all? { |key| dependency_allowed?(DataCycleCore::Feature[key], content) }
        end

        # How a dependent feature may hold this one: :allowed asks #allowed?(content), :enabled
        # holds it to #enabled? alone.
        #
        # :enabled is for a feature whose #allowed? cannot answer "is this available here?" from a
        # content -- Feature::Translate#allowed?(content, locale, source_locale, user) is the one in
        # tree, and generated_translation declares it, so asking it with a content alone would raise
        # ArgumentError rather than answer. #dependency_allowed? has established #enabled? by then,
        # which is why :enabled needs nothing further asked.
        #
        # Declared rather than inferred from the arity of #allowed?: Feature::Download#allowed?
        # (content, download_scopes = [:content]) has one required parameter today, and making the
        # second one required would otherwise flip every feature depending on download from
        # "checked" to "always allowed" with no error and no failing test.
        #
        # @return [Symbol] :allowed or :enabled
        def dependency_check
          :allowed
        end

        # Whether one declared dependency is allowed for this content.
        #
        # @param feature [Class, nil] the dependency, nil for a key no feature answers to
        # @param content [DataCycleCore::Thing, nil]
        # @return [Boolean]
        def dependency_allowed?(feature, content)
          return false if feature.nil? || !feature.enabled?
          return true if feature.try(:dependency_check) == :enabled

          feature.allowed?(content).present?
        end

        def attribute_keys(content = nil)
          configuration(content)['attribute_keys'] || []
        end

        def primary_attribute_key(content = nil)
          attribute_keys(content).first
        end

        def available?(content = nil)
          attribute_keys(content).present?
        end

        # Folds in #dependencies_allowed? the way #enabled? folds in #dependencies_enabled?, so a
        # feature composed onto a backend -- auto_geocode onto geocode, generated_translation onto
        # translate, the pixies onto content_classifier and embedding -- does not restate it. A
        # feature that declares no :dependencies: is unaffected: #dependencies is then empty and
        # #all? answers true.
        def allowed?(content = nil)
          enabled? && configuration(content)['allowed'] && dependencies_allowed?(content)
        end

        # Whether the user may write this attribute on this content, asked the way the editor asks
        # it: DataAttributeOptions#attribute_allowed? -> Ability#can_attribute?.
        #
        # Every feature that offers to write an attribute decides this identically, because what it
        # writes goes through the ordinary form and is governed by the ordinary per-attribute update
        # right. Asking `can?(:update, DataAttribute.new(key, definition, {}, content, :update))`
        # instead skips the four checks #can_attribute? layers on top -- an editor context
        # #can_edit_attribute?, #allowed_feature_attribute?, classification tree visibility, and the
        # rejection of an inverse `linked` -- and is therefore the more permissive of the two, which
        # is how a feature's endpoint comes to answer for an attribute whose editor the same user
        # never sees.
        #
        # It is therefore the right question only for a feature that writes through an editor. An
        # attribute a feature writes through an endpoint of its own has no editor to render, and
        # answers false here: focus_point_x and gravity are `:visible: api`, so #can_attribute?
        # rejects them while a bare `can?(:update, DataAttribute.new(...))` accepts them, which is
        # why Feature::FocusPointEditor and Feature::GravityEditor still ask the bare form. See
        # test/models/feature/attribute_editable_test.rb.
        #
        # @param content [DataCycleCore::Thing, nil]
        # @param key [String]
        # @param user [DataCycleCore::User, nil]
        # @return [Boolean]
        def attribute_editable?(content, key, user)
          return false if content.blank? || user.blank?

          definition = content.properties_for(key)
          return false if definition.blank?

          # edit_scope 'edit' because a feature asks about the detail edit form, which is where its
          # wand renders and which decides whether that attribute has an editor there at all
          editor_attribute_allowed?(key:, definition:, content:, user:, options: { edit_scope: 'edit' })
        end

        # The one construction of DataAttributeOptions behind that question, so the two ways of
        # asking it cannot drift apart. AttributeEditorHelper#attribute_editable? is the view's way
        # in and passes the definition and the options it already holds; #attribute_editable? above
        # looks the definition up and forces the edit scope, which is all that distinguished the
        # two.
        #
        # @return [Boolean]
        def editor_attribute_allowed?(key:, definition:, content:, user:, options: {}, scope: :update)
          DataCycleCore::DataAttributeOptions.new(
            key:,
            definition:,
            parameters: { options: },
            content:,
            user:,
            context: :editor,
            scope:
          ).attribute_allowed?
        end

        def allowed_attribute_keys(content = nil)
          allowed?(content) ? attribute_keys(content) : []
        end

        def allowed_attribute_key?(content, key)
          allowed?(content) && includes_attribute_key(content, key)
        end

        def includes_attribute_key(content, key) # rubocop:disable Naming/PredicateMethod
          template_keys = attribute_keys(content)

          key.attribute_path_from_key.intersect?(template_keys)
        end

        def configuration(content = nil, attribute_key = nil)
          @configuration ||= Hash.new do |h, key|
            schema = key[2]
            properties = key[3]

            config = ActiveSupport::HashWithIndifferentAccess.new
            config.merge!(DataCycleCore.features[feature_key.to_sym] || {})
            config.merge!(schema&.dig('features', feature_key) || {})
            config.merge!(properties&.filter_map { |k|
              schema&.dig('properties', *k, 'features', feature_key).presence&.merge({ attribute_keys: (k.is_a?(Array) ? [k.last] : [k]), tree_label: schema&.dig('properties', *k, 'tree_label') })
            }&.reduce({}) { |old, new| old.deep_merge(new) { |_, v1, v2| v1.is_a?(Array) && v2.is_a?(Array) ? v1 | v2 : v2 } } || {})

            h[key] = config.compact
          end

          @configuration[memoize_key(content, attribute_key)]
        end

        def content_module # rubocop:disable Naming/PredicateMethod
          false
        end

        def ability_class # rubocop:disable Naming/PredicateMethod
          false
        end

        def data_hash_module # rubocop:disable Naming/PredicateMethod
          false
        end

        def controller_module # rubocop:disable Naming/PredicateMethod
          false
        end

        def routes_module # rubocop:disable Naming/PredicateMethod
          false
        end

        def reload
          remove_instance_variable(:@configuration) if instance_variable_defined?(:@configuration)
          remove_instance_variable(:@enabled) if instance_variable_defined?(:@enabled)
          self
        end

        def memoize_key(content, key = nil)
          [
            feature_path,
            'configuration',
            content.try(:schema),
            if key.present?
              content.try(:collect_properties)&.select { |v| v.is_a?(::Array) ? v.include?(key.attribute_name_from_key) : v == key.attribute_name_from_key }
            else
              content.try(:collect_properties)
            end
          ]
        end

        def model_name
          FeatureBaseModel.new(self)
        end
      end
    end

    FeatureBaseModel = Struct.new(:klass) do
      def human(**)
        I18n.t("activerecord.models.#{klass.feature_path}", **)
      end
    end
  end
end
