# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

module DataCycleCore
  class DuplicateCandidateMergePlanTest < DataCycleCore::TestCases::ActiveSupportTestCase
    ID_A = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6f0a'
    ID_B = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6f0b'
    ID_C = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6f0c'
    ID_D = '6a2ee0a2-0c8f-4b0e-9c96-2e2a0a2f6f0d'

    def subject
      DataCycleCore::Feature::DuplicateCandidate::MergePlan
    end

    # the rows form the chain a-b, b-c: ID_A is the only one they never list as a duplicate, so
    # it survives although ID_B scores higher
    test 'joins pairs sharing an id into one transitive group' do
      plan = plan_for([[ID_A, ID_B], [ID_B, ID_C]], contents: [content(ID_A, score: 10), content(ID_B, score: 90), content(ID_C, score: 20)])

      assert_equal 1, plan.groups.size
      assert_equal [ID_A, ID_B, ID_C].sort, plan.groups.first.ids.sort
      assert_predicate plan.groups.first, :valid?
      assert_equal ID_A, plan.groups.first.original.id
      assert_equal [ID_B, ID_C].sort, plan.groups.first.duplicates.map(&:id).sort
    end

    # the status filter of MergeSpreadsheet decides what the plan gets to see: a 'Kein Treffer' row
    # must not drag its second content into the group its first one is merged into
    test 'a row skipped by its status keeps its content out of the group' do
      pairs = pairs_from_csv(<<~CSV)
        Original ID,Duplikat ID,Status
        #{ID_A},#{ID_B},Treffer
        #{ID_B},#{ID_C},Kein Treffer
      CSV

      plan = DataCycleCore::Thing.stub(:where, [content(ID_A), content(ID_B), content(ID_C)]) { subject.call(pairs) }

      assert_equal 1, plan.groups.size
      assert_equal [ID_A, ID_B].sort, plan.groups.first.ids.sort
      assert_equal ID_A, plan.groups.first.original.id
    end

    # the case the BVT file is full of: one original with a row per duplicate. the group has more
    # than two contents, which used to skip the column and let the content score decide.
    test 'a group of three keeps the original its Treffer rows name' do
      plan = plan_for(
        [[ID_A, ID_B, 'Treffer'], [ID_A, ID_C, 'Treffer']],
        contents: [content(ID_A, score: 10), content(ID_B, score: 90), content(ID_C, score: 20)]
      )

      assert_equal 1, plan.groups.size
      assert_equal ID_A, plan.groups.first.original.id
      assert_equal [ID_B, ID_C].sort, plan.groups.first.duplicates.map(&:id).sort
    end

    test 'a group of four keeps the original its Treffer rows name' do
      plan = plan_for(
        [[ID_A, ID_B, 'Treffer'], [ID_A, ID_C, 'Treffer'], [ID_A, ID_D, 'Treffer']],
        contents: [content(ID_A, score: 10), content(ID_B, score: 90), content(ID_C, score: 20), content(ID_D, score: 30)]
      )

      assert_equal ID_A, plan.groups.first.original.id
      assert_equal 3, plan.groups.first.duplicates.size
    end

    # 'Mehrdeutig' says the two contents are the same thing without saying which to keep
    test 'a Mehrdeutig group goes by the content score, not by the original column' do
      plan = plan_for(
        [[ID_A, ID_B, 'Mehrdeutig'], [ID_A, ID_C, 'Mehrdeutig']],
        contents: [content(ID_A, score: 10), content(ID_B, score: 90), content(ID_C, score: 20)]
      )

      assert_equal ID_B, plan.groups.first.original.id
    end

    test 'a Mehrdeutig pair goes by the content score' do
      plan = plan_for([[ID_A, ID_B, 'Mehrdeutig']], contents: [content(ID_A, score: 10), content(ID_B, score: 90)])

      assert_equal ID_B, plan.groups.first.original.id
    end

    # the Treffer row names ID_A, so the score of the content the Mehrdeutig row drags in must
    # not override it
    test 'a group mixing the two keeps the original of its Treffer row' do
      plan = plan_for(
        [[ID_A, ID_B, 'Treffer'], [ID_A, ID_C, 'Mehrdeutig']],
        contents: [content(ID_A, score: 10), content(ID_B, score: 90), content(ID_C, score: 20)]
      )

      assert_equal ID_A, plan.groups.first.original.id
      assert_equal [ID_B, ID_C].sort, plan.groups.first.duplicates.map(&:id).sort
    end

    # both rows call ID_B their duplicate, so the file names two originals for one group
    test 'a group whose rows name two originals falls back to the content score' do
      plan = plan_for(
        [[ID_A, ID_B, 'Treffer'], [ID_C, ID_B, 'Treffer']],
        contents: [content(ID_A, score: 10), content(ID_B, score: 20), content(ID_C, score: 90)]
      )

      assert_equal 1, plan.groups.size
      assert_equal ID_C, plan.groups.first.original.id
    end

    test 'a pair keeps the original the file names, even with the lower content score' do
      plan = plan_for([[ID_A, ID_B]], contents: [content(ID_A, score: 10), content(ID_B, score: 90)])

      assert_equal ID_A, plan.groups.first.original.id
      assert_equal [ID_B], plan.groups.first.duplicates.map(&:id)
    end

    test 'a pair listed twice still keeps the original the file names' do
      plan = plan_for([[ID_A, ID_B], [ID_A, ID_B]], contents: [content(ID_A, score: 10), content(ID_B, score: 90)])

      assert_equal 1, plan.groups.size
      assert_equal ID_A, plan.groups.first.original.id
    end

    # the rows contradict each other, so the column cannot decide it
    test 'a pair listed in both directions falls back to the content score' do
      plan = plan_for([[ID_A, ID_B], [ID_B, ID_A]], contents: [content(ID_A, score: 10), content(ID_B, score: 90)])

      assert_equal 1, plan.groups.size
      assert_equal ID_B, plan.groups.first.original.id
    end

    test 'keeps unrelated pairs in separate groups' do
      plan = plan_for([[ID_A, ID_B], [ID_C, ID_D]], contents: [content(ID_A), content(ID_B), content(ID_C), content(ID_D)])

      assert_equal 2, plan.groups.size
      assert_empty plan.errors
      assert_equal 2, plan.valid_groups.size
    end

    test 'reports a row that references itself' do
      plan = plan_for([[ID_A, ID_A]], contents: [content(ID_A)])

      assert_equal 1, plan.invalid_groups.size
      assert_match(/references itself/, plan.errors.join)
    end

    test 'reports an id that is not a uuid' do
      plan = plan_for([[ID_A, 'kein-uuid']], contents: [content(ID_A)])

      assert_empty plan.valid_groups
      assert_match(/'kein-uuid' is not a valid id/, plan.errors.join)
    end

    test 'reports an id without a content' do
      plan = plan_for([[ID_A, ID_B]], contents: [content(ID_A)])

      assert_empty plan.valid_groups
      assert_includes plan.errors.join, "content #{ID_B} does not exist"
    end

    test 'reports a group mixing templates' do
      plan = plan_for([[ID_A, ID_B]], contents: [content(ID_A, template_name: 'Örtlichkeit'), content(ID_B, template_name: 'Bild')])

      assert_empty plan.valid_groups
      assert_match(/mixes the templates/, plan.errors.join)
    end

    test 'keeps the groups without errors mergeable' do
      plan = plan_for([[ID_A, ID_B], [ID_C, 'kein-uuid']], contents: [content(ID_A), content(ID_B), content(ID_C)])

      assert_equal 1, plan.valid_groups.size
      assert_equal [ID_A, ID_B].sort, plan.valid_groups.first.ids.sort
      assert_equal 1, plan.invalid_groups.size
    end

    private

    # +pairs+ as [original_id, duplicate_id] or [original_id, duplicate_id, status] tuples, one
    # row per pair. without a status the row counts as directed, as in a file without the column.
    def plan_for(pairs, contents:)
      rows = pairs.each_with_index.map do |(original_id, duplicate_id, status), index|
        DataCycleCore::Feature::DuplicateCandidate::MergeSpreadsheet::Pair.new('default', index + 2, original_id, duplicate_id, status)
      end

      DataCycleCore::Thing.stub(:where, contents) { subject.call(rows) }
    end

    # pairs as MergeSpreadsheet produces them, so that its status filter is part of the test
    def pairs_from_csv(csv)
      file = Tempfile.new(['merge_plan', '.csv'])
      file.write(csv)
      file.close

      DataCycleCore::Feature::DuplicateCandidate::MergeSpreadsheet.call(file.path)
    ensure
      file&.unlink
    end

    def content(id, score: 50, template_name: 'Örtlichkeit', updated_at: Time.zone.now)
      struct_double(id:, template_name:, updated_at:, internal_content_score: score, available_locales: [:de])
    end
  end
end
