# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class EmbeddedMultipleTemplatesTest < ActiveSupport::TestCase
        def tester
          DataCycleCore::User.find_by(email: 'tester@datacycle.at')
        end

        test 'insert multiple embedded of different types' do
          data_set = DataCycleCore::TestPreparations.create_content(
            template_name: 'Embedded-Multiple-Templates-Entity-1',
            data_hash: {
              embedded_creative_work: [{
                name: 'test 1',
                template_name: 'Embedded-Multiple-Templates-1'
              }, {
                name: 'test 1',
                template_name: 'Embedded-Multiple-Templates-2'
              }]
            }
          )

          assert_equal ['Embedded-Multiple-Templates-1', 'Embedded-Multiple-Templates-2'], data_set.embedded_creative_work.pluck(:template_name)
        end

        test 'insert multiple embedded of different types without template_names raises Error on validation' do
          assert_raise(DataCycleCore::Error::TemplateNotAllowedError) do
            DataCycleCore::TestPreparations.create_content(
              template_name: 'Embedded-Multiple-Templates-Entity-1',
              data_hash: {
                embedded_creative_work: [{
                  name: 'test 1'
                }, {
                  name: 'test 1'
                }]
              }
            )
          end
        end

        # An APIv4 push writes the embedded content first and then re-sends it as a bare id, which
        # carries no template_name for the slot to resolve. The referenced content answers instead.
        test 'reference an existing embedded of an allowed type by id alone' do
          data_set = DataCycleCore::TestPreparations.create_content(
            template_name: 'Embedded-Multiple-Templates-Entity-1',
            data_hash: {
              name: 'reference by id',
              embedded_creative_work: [{
                name: 'test 1',
                template_name: 'Embedded-Multiple-Templates-1'
              }]
            }
          )
          embedded = data_set.embedded_creative_work.first

          data_set.set_data_hash(
            data_hash: { embedded_creative_work: [{ id: embedded.id }] },
            current_user: tester
          )

          assert_equal [embedded.id], data_set.reload.embedded_creative_work.pluck(:id)
          assert_equal ['Embedded-Multiple-Templates-1'], data_set.embedded_creative_work.pluck(:template_name)
        end

        # A push carries several references at once, which one item alone cannot show: that they
        # all resolve against the same lookup, and that set_embedded reorders the relation rather
        # than rebuilding it. Sent back in reverse for the latter.
        test 'reference several existing embedded of allowed types by id alone' do
          data_set = DataCycleCore::TestPreparations.create_content(
            template_name: 'Embedded-Multiple-Templates-Entity-1',
            data_hash: {
              name: 'reference several by id',
              embedded_creative_work: [{
                name: 'test 1',
                template_name: 'Embedded-Multiple-Templates-1'
              }, {
                name: 'test 2',
                template_name: 'Embedded-Multiple-Templates-2'
              }]
            }
          )
          embedded_ids = data_set.embedded_creative_work.pluck(:id)

          data_set.set_data_hash(
            data_hash: { embedded_creative_work: embedded_ids.reverse.map { |id| { id: } } },
            current_user: tester
          )

          assert_equal embedded_ids.reverse, data_set.reload.embedded_creative_work.pluck(:id)
          assert_equal ['Embedded-Multiple-Templates-2', 'Embedded-Multiple-Templates-1'], data_set.embedded_creative_work.pluck(:template_name)
        end

        # Embedded content may hang on more than one parent, and a reference is the only way to
        # get there. Dropping it from one parent has to leave the other intact -- set_embedded
        # destroys with check_ancestors, which spares content another parent still holds.
        test 'reference embedded content another entity already holds' do
          owner = DataCycleCore::TestPreparations.create_content(
            template_name: 'Embedded-Multiple-Templates-Entity-1',
            data_hash: {
              name: 'owner',
              embedded_creative_work: [{
                name: 'shared',
                template_name: 'Embedded-Multiple-Templates-1'
              }]
            }
          )
          shared_id = owner.embedded_creative_work.first.id
          borrower = DataCycleCore::TestPreparations.create_content(
            template_name: 'Embedded-Multiple-Templates-Entity-1',
            data_hash: { name: 'borrower' }
          )

          borrower.set_data_hash(data_hash: { embedded_creative_work: [{ id: shared_id }] }, current_user: tester)

          assert_equal [shared_id], borrower.reload.embedded_creative_work.pluck(:id)

          borrower.set_data_hash(data_hash: { embedded_creative_work: [] }, current_user: tester)

          assert_empty borrower.reload.embedded_creative_work
          assert_equal [shared_id], owner.reload.embedded_creative_work.pluck(:id)
        end

        # A bare id skips the payload validation, so the slot's template restriction has to be
        # taken from the referenced record -- otherwise any existing thing could be attached, and
        # set_embedded destroys whatever a later push drops from the relation.
        test 'reference a thing of a type the slot does not allow by id alone raises Error on validation' do
          bild = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Bild ausserhalb' })
          data_set = DataCycleCore::TestPreparations.create_content(
            template_name: 'Embedded-Multiple-Templates-Entity-1',
            data_hash: { name: 'reference foreign type' }
          )

          assert_raise(DataCycleCore::Error::TemplateNotAllowedError) do
            data_set.set_data_hash(
              data_hash: { embedded_creative_work: [{ id: bild.id }] },
              current_user: tester
            )
          end

          assert_empty data_set.reload.embedded_creative_work
        end

        # An unknown id used to pass validation and then fail on the content_contents foreign key.
        test 'reference a thing that does not exist by id alone raises Error on validation' do
          data_set = DataCycleCore::TestPreparations.create_content(
            template_name: 'Embedded-Multiple-Templates-Entity-1',
            data_hash: { name: 'reference unknown id' }
          )

          assert_raise(DataCycleCore::Error::TemplateNotAllowedError) do
            data_set.set_data_hash(
              data_hash: { embedded_creative_work: [{ id: SecureRandom.uuid }] },
              current_user: tester
            )
          end

          assert_empty data_set.reload.embedded_creative_work
        end

        test 'insert multiple embedded of different types with wrong template_names raises Error on validation' do
          assert_raise(DataCycleCore::Error::TemplateNotAllowedError) do
            DataCycleCore::TestPreparations.create_content(
              template_name: 'Embedded-Multiple-Templates-Entity-1',
              data_hash: {
                embedded_creative_work: [{
                  name: 'test 1',
                  template_name: 'Embedded-Creative-Work-2'
                }, {
                  name: 'test 1',
                  template_name: 'Embedded-Creative-Work-2'
                }]
              }
            )
          end
        end
      end
    end
  end
end
