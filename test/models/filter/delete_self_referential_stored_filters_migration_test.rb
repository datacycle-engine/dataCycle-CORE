# frozen_string_literal: true

require 'test_helper'
require DataCycleCore::Engine.root.join('db', 'data_migrate', '20260616161900_delete_self_referential_stored_filters')

module DataCycleCore
  # [#49832] Locks AK1: the data migration deletes self-referential stored filters - direct and
  # transitive, named and unnamed - while keeping valid ones.
  class DeleteSelfReferentialStoredFiltersMigrationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
    end

    def relation_param(target_id)
      { 'c' => 'a', 'm' => 'i', 'q' => 'copyright_holder', 't' => 'relation_filter', 'v' => target_id, 'n' => 'r' }
    end

    test 'deletes direct, transitive and unnamed self-referential filters, keeps valid ones (AK1)' do
      direct = DataCycleCore::StoredFilter.create!(name: 'direct', user_id: @user.id, language: ['de'])
      direct.update_columns(parameters: [relation_param(direct.id)])

      # transitive cycle A -> B -> A, with B unnamed (seeded bypassing the validation, like legacy data)
      cycle_a = DataCycleCore::StoredFilter.create!(name: 'cycle a', user_id: @user.id, language: ['de'])
      cycle_b = DataCycleCore::StoredFilter.create!(name: nil, user_id: @user.id, language: ['de'])
      cycle_a.update_columns(parameters: [relation_param(cycle_b.id)])
      cycle_b.update_columns(parameters: [relation_param(cycle_a.id)])

      valid = DataCycleCore::StoredFilter.create!(name: 'valid', user_id: @user.id, language: ['de'], parameters: [
                                                    { 'c' => 'a', 'm' => 'i', 'n' => 'Inhaltstypen', 't' => 'classification_alias_ids', 'v' => get_concept_ids('Inhaltstypen', 'Organisation') }
                                                  ])

      DeleteSelfReferentialStoredFilters.new.up

      assert_not(DataCycleCore::StoredFilter.exists?(direct.id), 'direct self-referential filter must be deleted')
      # both members of the transitive cycle must go - detection runs over the intact graph before any
      # deletion, otherwise removing one member would hide the other.
      assert_not(DataCycleCore::StoredFilter.exists?(cycle_a.id), 'transitive cycle (named) must be deleted')
      assert_not(DataCycleCore::StoredFilter.exists?(cycle_b.id), 'transitive cycle (unnamed) must be deleted')
      assert(DataCycleCore::StoredFilter.exists?(valid.id), 'valid filter must be kept')
    end

    test 'deleting via destroy drops any leftover SQL representation' do
      filter = DataCycleCore::StoredFilter.create!(name: 'with representation', user_id: @user.id, language: ['de'])
      filter.update_columns(parameters: [relation_param(filter.id)])
      function_name = filter.sql_representation_name
      DataCycleCore::StoredFilter.connection.execute(
        "CREATE OR REPLACE FUNCTION public.#{function_name}() RETURNS SETOF uuid LANGUAGE sql STABLE AS $$ SELECT NULL::uuid WHERE false $$;"
      )

      assert_predicate(function_exists?(function_name), :present?)

      DeleteSelfReferentialStoredFilters.new.up

      assert_not(DataCycleCore::StoredFilter.exists?(filter.id))
      assert_not(function_exists?(function_name), 'after_destroy must drop the SQL representation')
    end

    private

    def function_exists?(name)
      DataCycleCore::StoredFilter.connection.select_value(
        "SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname = #{DataCycleCore::StoredFilter.connection.quote(name)})"
      )
    end
  end
end
