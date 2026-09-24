# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      # [#51643] Compute::Base#load_missing_values resolves the :parameters: a compute has no value
      # for yet, and a parameter that carries a compute of its own is one of those. Which pass is
      # running decides what it owes: the pass the parameter belongs to has to compute it, every
      # later pass has the value that pass stored.
      class ComputedDeferredParameterTest < DataCycleCore::TestCases::ActiveSupportTestCase
        # Absolute counts elsewhere in the suite depend on no test leaving contents behind, and this
        # suite does not roll back between tests. The histories are deleted by the ids of the things
        # this file created, so a test file running before it keeps the rows it asserts on - and
        # after the destroy, which writes one history row more per content.
        after(:all) do
          thing_ids = DataCycleCore::Thing.where(template_name: ['Deferred-Compute-Article', 'Same-Pass-Chain-Article']).pluck(:id)

          DataCycleCore::Thing.where(id: thing_ids).destroy_all

          histories = DataCycleCore::Thing::History.where(thing_id: thing_ids)
          DataCycleCore::Thing::History::Translation.where(thing_history_id: histories.select(:id)).delete_all
          histories.delete_all
        end

        # The property keys Utility::Compute::Common.copy was asked for while the block ran, in
        # order. The real method is captured before it is stubbed, so each counted call still
        # computes.
        def copied_keys_while(&)
          keys = []
          original = DataCycleCore::Utility::Compute::Common.method(:copy)
          counting = lambda { |**args|
            keys.push(args[:key])
            original.call(**args)
          }

          DataCycleCore::Utility::Compute::Common.stub(:copy, counting, &)

          keys
        end

        def data_hash_of(content)
          content.reload.get_data_hash
        end

        # TestPreparations rather than the ActiveSupportTestCase helper, which drains the queue
        # right after the save - here the save and the job it schedules have to be watched apart.
        def create_article(template_name, name)
          DataCycleCore::TestPreparations.create_content(template_name:, data_hash: { 'name' => name })
        end

        test 'the compute.after_save pass reads the inline value the same save stored' do
          article = nil
          keys = copied_keys_while { article = create_article('Deferred-Compute-Article', 'Nach dem Speichern') }

          assert_equal('Nach dem Speichern', data_hash_of(article)['after_save_copy'])
          assert_equal(1, keys.count('after_save_copy'), 'the compute.after_save property has to be computed once')
          assert_equal(1, keys.count('inline_copy'), 'its parameter was computed by the inline pass of this save and must not be computed again')
        end

        test 'the compute.async job reads the inline value the save stored' do
          article = create_article('Deferred-Compute-Article', 'Im Job')
          keys = copied_keys_while { perform_enqueued_jobs }

          assert_equal('Im Job', data_hash_of(article)['async_copy'])
          assert_equal(1, keys.count('async_copy'), 'the compute.async property has to be computed once')
          assert_equal(0, keys.count('inline_copy'), 'its parameter was computed by the save that scheduled the job and must not be computed again')
        end

        # Where both links share a deferral there is no earlier pass that could have stored the
        # parameter - on a create neither has ever been written - so the reading compute has to
        # compute it, whatever the record happens to hold. Driven key by key, because the
        # transformed template orders inline_first before inline_second and the pass would
        # otherwise have computed it already.
        test 'an inline compute computes the inline parameter it reads' do
          article = create_article('Same-Pass-Chain-Article', 'Inline-Kette')
          keys = copied_keys_while { article.update_computed_values(keys: ['inline_second']) }

          assert_equal(['inline_first', 'inline_second'], keys)
          assert_equal('Inline-Kette', data_hash_of(article)['inline_second'])
        end

        test 'a compute.async compute computes the compute.async parameter it reads' do
          article = create_article('Same-Pass-Chain-Article', 'Job-Kette')
          perform_enqueued_jobs
          keys = copied_keys_while { article.update_computed_values(keys: ['async_second']) }

          assert_equal(['async_first', 'async_second'], keys)
          assert_equal('Job-Kette', data_hash_of(article)['async_second'])
        end
      end
    end
  end
end
