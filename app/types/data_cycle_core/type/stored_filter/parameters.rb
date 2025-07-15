# frozen_string_literal: true

module DataCycleCore
  module Type
    module StoredFilter
      class Parameters < ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Jsonb
        FILTER_PREFIX = {
          'e' => 'not_',
          'g' => 'greater_',
          'l' => 'lower_',
          's' => 'like_',
          'u' => 'not_like_',
          'b' => 'not_exists_',
          'p' => 'exists_'
        }.freeze

        delegate :param_from_definition, to: :class

        def cast(value)
          return super if value.blank?

          super(Array.wrap(value).map { |filter| param_from_definition(filter) })
        end

        def self.param_from_definition(definition, type = 'a', user = nil)
          return if definition.blank?

          filter = definition.to_h.deep_stringify_keys

          return filter if filter.key?('t')

          filter.each_with_object({}) do |(k, v), hash|
            hash['t'], hash['m'] = filter_method_from_prefix(k)
            hash['v'] = v
            hash['c'] = type
            hash['n'] = hash['t'].capitalize

            custom_param_transformation(hash, user)
          end
        end

        def self.custom_param_transformation(hash, user)
          case hash['t']
          when 'union'
            hash['n'] = hash.dig('v', 'name') if hash['v'].is_a?(::Hash) && hash.dig('v', 'name').present?
            hash['v'] = Array.wrap(hash['v'].is_a?(::Hash) ? hash.dig('v', 'stored_filter') : hash['v'])
              .map { |s| param_from_definition(s, hash['c'], user) }
          when 'with_classification_aliases_and_treename'
            raise StandardError, 'Missing data definition: treeLabel' if hash.dig('v', 'treeLabel').blank?
            raise StandardError, 'Missing data definition: aliases' if hash.dig('v', 'aliases').blank?

            hash['t'] = 'classification_alias_ids'
            hash['n'] = hash.dig('v', 'treeLabel')
            hash['v'] = DataCycleCore::ClassificationAlias
              .for_tree(hash.dig('v', 'treeLabel'))
              .with_internal_name(hash.dig('v', 'aliases')).pluck(:id)
          when 'with_classification_paths'
            hash['t'] = 'classification_alias_ids'
            hash['n'] = Array.wrap(hash['v']).map { |v| v&.split(' > ')&.first }.join(', ')
            hash['v'] = DataCycleCore::ClassificationAlias.by_full_paths(hash['v']).pluck(:id)
          when 'external_source'
            hash['t'] = 'external_system'
            hash['n'] = hash['t'].capitalize
            hash['q'] = 'import'
          when 'external_system'
            hash['v'], hash['q'] = hash['v'].values_at('value', 'type') if hash['v'].is_a?(::Hash)
            hash['n'] = hash['t'].capitalize
            hash['q'] ||= 'import'
          when 'user_group_classifications'
            hash['v'] = user&.id
          when 'creator'
            hash['t'] = 'user'
            hash['n'] = 'creator'
            hash['q'] = 'creator'
          when 'with_user_group_classifications_for_treename'
            raise StandardError, 'Missing data definition: treeLabel' if hash['v'].blank?
            relation = DataCycleCore::Feature::UserGroupClassification.attribute_relations.find { |_k, v| v['tree_label'] == hash['v'] }&.first
            raise StandardError, "relation not found for UserGroup and treelabel (#{hash['v']})" if relation.blank?

            hash['t'] = 'classification_alias_ids'
            hash['n'] = hash['v']
            hash['v'] = user&.user_groups&.send(relation)&.pluck(:id)
          when 'graph_filter'
            hash['n'] = hash.dig('v', 'query')
            hash['q'] = hash.dig('v', 'name')
            hash['v'] = hash.dig('v', 'value')
          end

          transform_placeholders(hash, user)
        end

        def self.transform_placeholders(hash, user)
          if hash['v'].is_a?(::Array) && hash['v'].include?('current_user')
            hash['v'] = hash['v'].map { |v| v == 'current_user' ? user&.id : v }
          elsif hash['v'].is_a?(::String) && hash['v'] == 'current_user'
            hash['v'] = user&.id
          end
        end

        def self.filter_method_from_prefix(filter_type)
          f_method, f_prefix = FILTER_PREFIX.to_a.reverse.find { |_, prefix| filter_type.starts_with?(prefix) }

          return filter_type.delete_prefix(f_prefix.to_s), f_method || 'i'
        end
      end
    end
  end
end
