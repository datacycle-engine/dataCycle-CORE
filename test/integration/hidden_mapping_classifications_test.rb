# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Redmine #50677: a concept a content only carries through a mapping of a tree flagged with
  # hidden_mappings is excluded everywhere — except from the collapsed ("weitere Klassifizierungen")
  # area of the detail view, where super_admin and above see it marked with an icon.
  class HiddenMappingClassificationsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @source_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "HiddenDetailSrc_#{SecureRandom.hex(6)}", visibility: ['show'])
      @src = @source_tree.create_classification_alias('HIDDEN DETAIL SRC')

      @target_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "HiddenDetailTgt_#{SecureRandom.hex(6)}", visibility: ['show'])
      @tt = @target_tree.create_classification_alias('HIDDEN DETAIL TARGET')
      DataCycleCore::ClassificationGroup.create!(classification: @src.primary_classification, classification_alias: @tt)
      @target_tree.update!(hidden_mappings: true)

      @content = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: { name: 'HiddenMappingDetailProbe', universal_classifications: [@src.primary_classification.id] }
      )

      @super_admin = create_user(99)
      @admin = create_user(10)
    end

    # the scenario is built once for the whole class and a local test DB outlives the run — a leftover
    # tree with hidden_mappings would go on hiding mappings for every test after it. Soft delete, not
    # destroy_fully!: the mapping makes the two trees' dependent associations reference each other, and
    # acts_as_paranoid walks that cycle until the stack runs out.
    after(:all) do
      @content&.destroy_content
      [@target_tree, @source_tree].compact.each(&:destroy)
      [@super_admin, @admin].compact.each(&:destroy)
    end

    test 'a super admin sees the hidden mapping in the collapsed area, marked with an icon' do
      sign_in(@super_admin)

      get thing_path(@content)

      assert_response :success
      assert_select '.hidden-classifications .tag.hidden-mapping', text: /#{@tt.internal_name}/
      assert_select '.hidden-classifications .tag.hidden-mapping i.fa-eye-slash'
      # rendered exactly once, and only inside the collapsed area
      assert_select '.tag.hidden-mapping', 1
    end

    # the same concept can be direct in one relation and mapped-hidden in another (e.g. #47053's
    # effective classification): it is already displayed, so it is not repeated as a hidden mapping
    test 'a concept the content also carries visibly is not repeated in the collapsed area' do
      sign_in(@super_admin)
      @content.set_data_hash(data_hash: { name: 'HiddenMappingDetailProbe', universal_classifications: [@src.primary_classification.id, @tt.primary_classification.id] })

      get thing_path(@content)

      assert_response :success
      assert_select '.tag.hidden-mapping', count: 0
      assert_select '.tag', text: /#{@tt.internal_name}/
    ensure
      @content.set_data_hash(data_hash: { name: 'HiddenMappingDetailProbe', universal_classifications: [@src.primary_classification.id] })
    end

    test 'an admin sees no hidden mapping at all' do
      sign_in(@admin)

      get thing_path(@content)

      assert_response :success
      assert_select '.tag.hidden-mapping', count: 0
      assert_select '.tag', text: /#{@tt.internal_name}/, count: 0
    end

    private

    def create_user(rank)
      DataCycleCore::User.create!(
        DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
          email: "hidden_mapping_#{rank}_#{SecureRandom.hex(4)}@datacycle.at",
          confirmed_at: 1.day.ago,
          role_id: DataCycleCore::Role.find_by(rank:)&.id
        })
      )
    end
  end
end
