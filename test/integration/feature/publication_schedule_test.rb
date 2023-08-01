# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class PublicationScheduleTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        DataCycleCore::Thing.delete_all
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      test 'add publication schedules to content' do
        publication_date = Time.zone.now
        classification_tree_labels = DataCycleCore::Feature::PublicationSchedule.classification_tree_labels(@content)
        assert classification_tree_labels.present?

        classifications = classification_tree_labels.transform_values do |c|
          DataCycleCore::ClassificationAlias.for_tree(c)&.map(&:primary_classification)
        end
        assert classifications.values.all?(&:present?)

        publication_schedules = Array.new(2) do |i|
          {
            datahash: classifications.transform_values { |c| [c[i].id] }.merge({
              DataCycleCore::Feature::PublicationSchedule.publication_date_key(@content) => publication_date
            })
          }
        end

        patch thing_path(@content), params: {
          thing: {
            datahash: {
              DataCycleCore::Feature::PublicationSchedule.attribute_keys(@content)&.first => publication_schedules
            }
          },
          save_and_close: true
        }, headers: {
          referer: edit_thing_path(@content)
        }

        assert_redirected_to thing_path(@content, locale: I18n.locale)
        assert_equal I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]
        assert_equal 2, @content.try(DataCycleCore::Feature::PublicationSchedule.attribute_keys(@content)&.first).reload.size
      end

      test 'search publication schedules' do
        publication_date = Time.zone.now.to_date.to_s

        classification_tree_labels = DataCycleCore::Feature::PublicationSchedule.classification_tree_labels(@content)
        assert classification_tree_labels.present?

        classifications = classification_tree_labels.transform_values do |c|
          DataCycleCore::ClassificationAlias.for_tree(c)&.map(&:primary_classification)
        end
        assert classifications.values.all?(&:present?)

        @content_with_publication_schedule = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: {
          'name' => 'PublicationScheduleTestArtikel',
          DataCycleCore::Feature::PublicationSchedule.attribute_keys(@content)&.first => [
            classifications.transform_values { |c| [c.first.id] }.merge({
              DataCycleCore::Feature::PublicationSchedule.publication_date_key(@content) => publication_date
            })
          ]
        })

        assert @content_with_publication_schedule.reload.try(DataCycleCore::Feature::PublicationSchedule.attribute_keys(@content)&.first).present?

        get publications_path, params: {
          publications_from: publication_date,
          publications_until: publication_date,
          f: classifications.map.with_index { |(k, v), i|
            [i.to_s, {
              c: 'd',
              t: 'classification_alias_ids',
              n: classification_tree_labels[k],
              m: 'i',
              v: [v.first.primary_classification_alias.id]
            }]
          }.to_h.merge({
            'ct' => {
              c: 'd',
              t: 'classification_alias_ids',
              n: 'Inhaltstypen',
              m: 'i',
              v: [@content_with_publication_schedule.data_type.first.primary_classification_alias.id]
            }
          })
        }, headers: {
          referer: publications_path
        }

        assert_response :success
        assert_select 'li.publication-content > .flex > .title > a > .title', { count: 1, text: 'PublicationScheduleTestArtikel' }
      end
    end
  end
end
