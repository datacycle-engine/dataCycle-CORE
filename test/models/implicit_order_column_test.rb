# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Models on a relation without a primary key - a database view, or a table that only carries a
  # unique constraint - give ActiveRecord nothing to order by. Since Rails 8.1
  # (`raise_on_missing_required_finder_order_columns`) the order dependent finders raise
  # ActiveRecord::MissingRequiredOrderError on such a model unless it declares an
  # `implicit_order_column`; before that, #last already raised IrreversibleOrderError.
  #
  # The set is derived from the schema rather than listed, so a model added later is covered too.
  class ImplicitOrderColumnTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # @return [Array<Class>] every loaded model whose relation has no primary key
    def self.models_without_primary_key
      Rails.application.eager_load!

      ActiveRecord::Base.descendants.reject(&:abstract_class?).select do |model|
        model.table_exists? && model.primary_key.nil? && model.query_constraints_list.nil?
      rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
        false
      end
    end

    test 'every model without a primary key declares an implicit_order_column' do
      undeclared = self.class.models_without_primary_key.reject(&:implicit_order_column)

      assert_empty(undeclared.map(&:name), 'models without a primary key need an implicit_order_column')
    end

    test 'ordered finders on models without a primary key run against the database' do
      failed = self.class.models_without_primary_key.filter_map do |model|
        model.first
        model.second
        model.last
        nil
      rescue StandardError => e
        "#{model.name}: #{e.class}"
      end

      assert_empty(failed, 'order dependent finders raised')
    end

    test 'ordered finders on associations without a default order do not raise' do
      thing = create_content('Artikel', { name: 'implicit order column' })

      assert_nothing_raised do
        thing.property_dependencies.first
        thing.property_dependencies.last
        thing.dependent_properties.first
        thing.data_link_content_items.first
        thing.content_content_links_a.first
      end
    end
  end
end
