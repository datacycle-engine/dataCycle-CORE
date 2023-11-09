# frozen_string_literal: true

module DataCycleCore
  class StoredFilter < ApplicationRecord
    # Mögliche Filter-Parameter: c, t, v, m, n, q
    #
    # c => one of 'd', 'a', 'p', 'u', 'uf'                | für 'default', 'advanced', 'permanent advanced', 'user', 'user forced'
    # t => String                                         | der Filtertyp (die Methode, die auf die Query ausgeführt wird, z.B. 'classification_alias_ids')
    # v => String, Array, Hash                            | der übergebene Wert für die Filtermethode (z.B. ['a9b25ff1-5af2-4f21-b61e-408812e14b0d'])
    # m => 'i', 'e', 'g', 'l', 'u', 'n', 's', 'b', 'p'    | Filtermethode, 'include', 'exclude', 'greater', 'lower', 'neutral', 'like', 'notLike', 'blank', 'present'
    # n => String                                         | das Filterlabel (z.B. 'Inhaltspools')
    # q => String (Optional)                              | Ein spezifischer Query-Pfad für das Attribut (z.B. metadata ->> 'width') || type

    include StoredFilterExtensions::SortParamTransformations
    include StoredFilterExtensions::FilterParamsTransformations
    include StoredFilterExtensions::FilterParamsHashParser

    default_scope { includes(:collection_configuration) }

    scope :by_user, ->(user) { where(user:) }
    scope :by_api_user, ->(user) { where("'#{user.id}' = ANY (api_users)") }
    scope :named, -> { where.not(name: nil) }
    belongs_to :user

    has_many :activities, as: :activitiable, dependent: :destroy

    belongs_to :linked_stored_filter, class_name: 'DataCycleCore::StoredFilter', inverse_of: :filter_uses, dependent: nil
    has_many :filter_uses, class_name: 'DataCycleCore::StoredFilter', foreign_key: :linked_stored_filter_id, inverse_of: :linked_stored_filter, dependent: :nullify

    has_many :data_links, as: :item, dependent: :destroy
    has_many :valid_write_links, -> { valid.writable }, class_name: 'DataCycleCore::DataLink', as: :item

    has_one :collection_configuration
    accepts_nested_attributes_for :collection_configuration, update_only: true
    delegate :slug, to: :collection_configuration, allow_nil: true

    before_save :update_slug, if: :update_slug?

    attr_accessor :query

    KEYS_FOR_EQUALITY = ['t', 'c', 'n'].freeze

    def apply(query: nil, skip_ordering: false, watch_list: nil)
      self.query = query || DataCycleCore::Filter::Search.new(language&.exclude?('all') ? language : nil)

      apply_filter_parameters
      apply_order_parameters(watch_list) unless skip_ordering

      self.query
    end

    def filter_equal?(filter1, filter2)
      filter1.slice(*KEYS_FOR_EQUALITY) == filter2.slice(*KEYS_FOR_EQUALITY)
    end

    def self.combine_with_collections(collections, filter_proc, name_filter = true)
      query1_table = all.arel_table
      query1 = all.arel
      query1.projections = []
      query1 = query1.where(query1_table[:name].not_eq(nil)) if name_filter
      query1 = query1.project(query1_table[:id], query1_table[:name], Arel::Nodes::SqlLiteral.new("'#{all.klass.model_name.param_key}'").as('class_name'))

      query2_table = collections.arel_table
      query2 = collections.arel
      query2.projections = []
      query2 = query2.where(query2_table[:name].not_eq(nil)).project(query2_table[:id], query2_table[:name], Arel::Nodes::SqlLiteral.new("'#{collections.klass.model_name.param_key}'").as('class_name'))

      unless filter_proc.nil?
        query1 = filter_proc.call(query1, query1_table)
        query2 = filter_proc.call(query2, query2_table)
      end

      Arel::SelectManager.new(Arel::Nodes::TableAlias.new(query1.union(:all, query2), 'combined_collections_and_searches')).project(Arel.star).order('name ASC')
    end

    def to_select_option
      DataCycleCore::Filter::SelectOption.new(
        id,
        name.presence || '__DELETED__',
        model_name.param_key,
        name.presence || '__DELETED__'
      )
    end

    def valid_write_links?
      valid_write_links.present?
    end

    def self.by_id_or_slug(value)
      return none if value.blank?

      uuids = Array.wrap(value).filter { |v| v.to_s.uuid? }
      slugs = Array.wrap(value)
      queries = []
      queries.push(unscoped.where(id: uuids).select(:id).to_sql) if uuids.present?
      queries.push(DataCycleCore::CollectionConfiguration.where.not(stored_filter_id: nil).where(slug: slugs).select(:stored_filter_id).to_sql) if slugs.present?

      where("stored_filters.id IN (#{send(:sanitize_sql_array, [queries.join(' UNION ')])})")
    end

    private

    def update_slug?
      name_changed? && slug.blank?
    end

    def update_slug
      self.collection_configuration_attributes = { slug: name&.to_slug }
    end
  end
end
