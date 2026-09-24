# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # An adapter that reuses the advanced-attribute filter logic of the public v4 API (ApiService)
    # without a controller or request context -- so MCP attribute filters behave exactly like the
    # REST parameter filter[attribute][<apiName>][in|notIn][min|max|equals|like|bool].
    # ApiService is a mixin full of controller instance methods, but the chain used here
    # (apply_attribute_filters plus mapping/transform/discovery helpers) is stateless (only
    # ContentProperties lookups and the global feature config), so it works as a standalone object.
    class AttributeFilter
      include DataCycleCore::ApiService
      include DataCycleCore::Mcp::BadRequest

      # Scalar types with a *_advanced_<type> handler in Filter::Common::Advanced that filter
      # reliably through the ApiService path (in|notIn → min|max|equals|like|bool).
      # Deliberately without object (no handler) and without nested paths (address.x), whose type
      # resolution does not work in the shared code -- which keeps discovery honest about the filter.
      FILTERABLE_TYPES = ['number', 'numeric', 'string', 'boolean', 'date', 'date_range', 'time', 'slug'].freeze

      # Applies structured attribute conditions to a Filter::Search and returns it.
      # conditions: array of { attribute:, in?: {min|max|equals|like|bool}, not_in?: {...} }.
      def apply(query, conditions)
        filters = build_filters(conditions)
        return query if filters.blank?

        apply_attribute_filters(query, filters)
      end

      # Discovery: the actually filterable advanced_search attributes (optionally restricted to the
      # endpoint's templates) as
      # [{ attribute: api_name, type: property_type, label:, unit: }], alphabetical, deduplicated.
      # @param template_names [Array<String>, nil] nil = no restriction (instance-wide),
      #   an array = EXACTLY these templates. An EMPTY array means "no templates" and therefore
      #   returns nothing.
      #
      #   The distinction between nil and [] is not cosmetic: callers derive the list from the
      #   CONTENTS of the mount (Tools::Base#scope_template_names). An endpoint without contents --
      #   or one whose contents do not include the filtered template -- returns [] there. With
      #   `present?` the scope then fell away and discovery ran instance-wide: list_attributes named
      #   attributes that do not exist in this endpoint at all, and the unit in applied_filters came
      #   from some arbitrary foreign template. Concretely, "width" carries metre in the Product
      #   mixin and pixel in Image/PDF/Video -- which of the two a client was told was decided by
      #   the database's row order.
      def available(template_names = nil)
        scope = DataCycleCore::ContentProperties
          .where(advanced_search: true, property_type: FILTERABLE_TYPES)
          .where.not(api_name: nil)
        scope = scope.where(template_name: template_names) unless template_names.nil?

        scope.distinct.pluck(:api_name, :property_type, :property_definition)
          .reject { |api_name, _type, _definition| api_name.include?('.') }
          .group_by { |api_name, type, _definition| [api_name, type] }
          .map { |(api_name, type), rows| describe(api_name, type, rows.map(&:third)) }
          .sort_by { |entry| entry[:attribute].to_s }
      end

      private

      # Adds label and unit from the property definition. Without a unit a numeric filter is not
      # safely usable: odta:length stores metres, so a client would pass "under 15 km" as max: 15
      # and get almost every hit removed instead of the tours that are too long. Several templates
      # can carry the same api_name -- the first definition that sets the respective value wins.
      def describe(api_name, type, definitions)
        definitions = definitions.map { |definition| definition.presence || {} }

        {
          attribute: api_name,
          type:,
          # String labels only: a label can also be an i18n key hash ({ key:, key_suffix: }) whose
          # resolution (Thing#human_attribute_name) needs a content instance as :base -- here the
          # description collects definitions ACROSS several templates, so there is no single
          # instance to resolve against. A raw hash in the tool output would be worse than no label.
          # (Mcp::WritableAttributes describes exactly one template and therefore does resolve.)
          label: first_present(definitions) { |d| d['label'] if d['label'].is_a?(::String) },
          unit: first_present(definitions) { |d| d.dig('api', 'unit_text') || d.dig('api', 'unit_code') }
        }.compact
      end

      def first_present(definitions)
        definitions.filter_map { |definition| yield(definition).presence }.first
      end

      # Builds the { <attribute> => { in|notIn => {...} } } structure apply_attribute_filters expects.
      #
      # A condition without a usable in/not_in is a request error and NOT a no-op: skipped silently,
      # the call returns the unfiltered total while applied_filters still names the attribute -- so
      # the response looks filtered and would read as "that many exist with this attribute". An
      # unknown attribute name raises at this point anyway ("attribute is unknown"), so an unusable
      # condition is treated the same way.
      def build_filters(conditions)
        Array.wrap(conditions).each_with_object({}).with_index do |(condition, filters), index|
          condition = condition.to_h.deep_symbolize_keys
          attribute = condition[:attribute]
          bad_request!("attributes[#{index}]", 'attribute must not be blank') if attribute.blank?

          operator = {}
          operator[:in] = condition[:in].to_h.deep_symbolize_keys if condition[:in].present?
          operator[:notIn] = condition[:not_in].to_h.deep_symbolize_keys if condition[:not_in].present?
          bad_request!("attributes[#{index}]", "condition for '#{attribute}' needs at least one of in/not_in with min|max|equals|like|bool") if operator.blank?

          filters[attribute.to_sym] = operator
        end
      end
    end
  end
end
