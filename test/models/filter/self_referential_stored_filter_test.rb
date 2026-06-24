# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # [#49832] A self-referential stored filter resolves to itself and can never be executed (infinite
  # recursion). It is self-referential when following its relation/filter_ids references - directly or
  # transitively - leads back to itself. Such filters must be rejected on save instead of being
  # persisted and only failing later at query time.
  class SelfReferentialStoredFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
    end

    def relation_param(target_id)
      { 'c' => 'a', 'm' => 'i', 'n' => 'rel', 'q' => 'copyright_holder', 't' => 'relation_filter', 'v' => target_id }
    end

    # AK2 ("cannot be created") holds by construction: a brand-new record has no id until the database
    # assigns it on insert, so its parameters cannot reference its own (not-yet-existing) id. The
    # normal create path therefore can never produce a self-referential filter - it is the *update*
    # vector (AK3) that the validation actually guards.
    test 'a plain create cannot be self-referential because the id does not exist yet (AK2)' do
      [
        { 'c' => 'a', 'm' => 'i', 'n' => 'self', 'q' => 'copyright_holder', 't' => 'relation_filter', 'v' => 'irrelevant' },
        { 'c' => 'a', 'm' => 'i', 'n' => 'self', 't' => 'filter_ids', 'v' => ['irrelevant'] },
        { 'c' => 'a', 'm' => 'i', 'n' => 'self', 't' => 'union_filter_ids', 'v' => ['irrelevant'] }
      ].each do |parameter|
        stored_filter = DataCycleCore::StoredFilter.new(name: 'fresh', user_id: @user.id, language: ['de'], parameters: [parameter])

        assert_not(stored_filter.self_referential?, "a new record cannot self-reference via #{parameter['t']}")
        assert(stored_filter.save, "a non-self-referential create must succeed (#{parameter['t']})")
      end
    end

    # Defense in depth: should a create ever carry an explicit id (the app does not do this today),
    # the validation still rejects a self-reference rather than relying solely on the by-construction
    # guarantee above.
    test 'a create with an explicit id that references itself is still rejected (AK2)' do
      id = SecureRandom.uuid
      stored_filter = DataCycleCore::StoredFilter.new(id:, name: 'self ref', user_id: @user.id, language: ['de'], parameters: [
                                                        { 'c' => 'a', 'm' => 'i', 'n' => 'self', 'q' => 'copyright_holder', 't' => 'relation_filter', 'v' => id }
                                                      ])

      assert_not(stored_filter.save)
      assert_predicate(stored_filter, :new_record?)
      assert(stored_filter.errors.added?(:parameters, :self_referential), 'expected a :self_referential error on :parameters')
    end

    test 'an existing stored filter cannot be converted into a self-referential one (AK3)' do
      stored_filter = DataCycleCore::StoredFilter.create!(name: 'savable', user_id: @user.id, language: ['de'])

      assert_not(
        stored_filter.update(parameters: [{
          'c' => 'a', 'm' => 'i', 'n' => 'self', 'q' => 'copyright_holder',
          't' => 'relation_filter', 'v' => stored_filter.id
        }])
      )
      assert(stored_filter.errors.added?(:parameters, :self_referential), 'expected a :self_referential error on :parameters')
      assert_predicate(stored_filter.reload.parameters, :blank?, 'rejected parameters must not be persisted')
    end

    test 'a stored filter referencing a different stored filter is valid' do
      other = DataCycleCore::StoredFilter.create!(name: 'other', user_id: @user.id, language: ['de'])
      stored_filter = DataCycleCore::StoredFilter.new(name: 'references other', user_id: @user.id, language: ['de'], parameters: [relation_param(other.id)])

      assert_predicate(stored_filter, :valid?)
      assert_not(stored_filter.self_referential?)
    end

    test 'a transitive cycle A -> B -> A is detected (AK3)' do
      filter_a = DataCycleCore::StoredFilter.create!(name: 'A', user_id: @user.id, language: ['de'])
      filter_b = DataCycleCore::StoredFilter.create!(name: 'B', user_id: @user.id, language: ['de'], parameters: [relation_param(filter_a.id)])

      assert_not(filter_a.update(parameters: [relation_param(filter_b.id)]))
      assert(filter_a.errors.added?(:parameters, :self_referential))
      assert_predicate(filter_a.reload.parameters, :blank?)
    end

    test 'a deeper transitive cycle A -> B -> C -> A is detected (AK3)' do
      filter_a = DataCycleCore::StoredFilter.create!(name: 'A', user_id: @user.id, language: ['de'])
      filter_b = DataCycleCore::StoredFilter.create!(name: 'B', user_id: @user.id, language: ['de'])
      filter_c = DataCycleCore::StoredFilter.create!(name: 'C', user_id: @user.id, language: ['de'], parameters: [relation_param(filter_a.id)])
      filter_b.update!(parameters: [relation_param(filter_c.id)])

      assert_not(filter_a.update(parameters: [relation_param(filter_b.id)]))
      assert(filter_a.errors.added?(:parameters, :self_referential))
      assert_predicate(filter_a.reload.parameters, :blank?)
    end

    test 'a non-cyclic reference chain A -> B -> C is valid and terminates' do
      filter_c = DataCycleCore::StoredFilter.create!(name: 'C', user_id: @user.id, language: ['de'])
      filter_b = DataCycleCore::StoredFilter.create!(name: 'B', user_id: @user.id, language: ['de'], parameters: [relation_param(filter_c.id)])
      filter_a = DataCycleCore::StoredFilter.new(name: 'A', user_id: @user.id, language: ['de'], parameters: [relation_param(filter_b.id)])

      assert_not(filter_a.self_referential?)
      assert_predicate(filter_a, :valid?)
    end

    test 'a non-relation parameter (e.g. a classification) whose value coincidentally equals the id is not flagged (and not treated as a self-reference)' do
      stored_filter = DataCycleCore::StoredFilter.create!(name: 'coincidence', user_id: @user.id, language: ['de'])
      stored_filter.parameters = [{ 'c' => 'a', 'm' => 'i', 'n' => 'Inhaltstypen', 't' => 'classification_alias_ids', 'v' => [stored_filter.id] }]

      assert_not(stored_filter.self_referential?)
      assert_predicate(stored_filter, :valid?)
    end

    test 'a brand new unsaved filter without an id is not self-referential' do
      assert_not(DataCycleCore::StoredFilter.new(parameters: [{ 't' => 'relation_filter', 'v' => 'whatever' }]).self_referential?)
    end

    test 'the self-reference validation does not run when only non-parameter attributes change (AK4/AK5)' do
      stored_filter = DataCycleCore::StoredFilter.create!(name: 'valid', user_id: @user.id, language: ['de'], parameters: [
                                                            { 'c' => 'a', 'm' => 'i', 'n' => 'Inhaltstypen', 't' => 'classification_alias_ids', 'v' => get_concept_ids('Inhaltstypen', 'Organisation') }
                                                          ])

      # Count actual invocations of the (potentially expensive) check: a name-only save must skip it
      calls = count_self_referential_calls(stored_filter) { stored_filter.update!(name: 'renamed only') }

      assert_equal(0, calls, 'name-only change must not run the self-reference check')

      calls = count_self_referential_calls(stored_filter) do
        stored_filter.update!(parameters: [{ 'c' => 'a', 'm' => 'i', 'n' => 'Suchbegriff', 't' => 'fulltext_search', 'v' => 'x' }])
      end

      assert_operator(calls, :>=, 1, 'a parameters change must run the self-reference check')
    end

    private

    # Run the block while counting how many times #self_referential? is invoked on the given record.
    def count_self_referential_calls(record, &)
      calls = 0
      record.stub(:self_referential?, -> { calls += 1 and false }, &)
      calls
    end
  end
end
