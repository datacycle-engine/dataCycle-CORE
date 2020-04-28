# frozen_string_literal: true

module DataCycleCore
  module V4
    module DummyDataHelper
      module_function

      def create_data(type, user = nil)
        @user = user
        send(type)
        # rescue StandardError
        #   raise ArgumentError, 'Unknown type for ApiV4DummyDataHelper'
      end

      def poi
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'v4_poi')
        data_hash['name'] = "poi_#{SecureRandom.uuid}"
        data_hash['validity_period'] = validity_period
        data_hash['image'] = [image.id]
        DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: data_hash, user: @user)
      end

      def food_establishment
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'v4_food_establishment')
        data_hash['name'] = "food_establishment_#{SecureRandom.uuid}"
        data_hash['validity_period'] = validity_period
        data_hash['image'] = [image.id]
        DataCycleCore::TestPreparations.create_content(template_name: 'Gastronomischer Betrieb', data_hash: data_hash, user: @user)
      end

      def image
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('media_objects', 'v4_image')
        data_hash['name'] = "image_#{SecureRandom.uuid}"
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data_hash, user: @user)
      end

      def event
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'v4_event')
        data_hash['event_schedule'] = [schedule]
        data_hash['validity_period'] = validity_period
        data_hash['offers'] = [offer]
        DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: data_hash, user: @user)
      end

      def offer
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('intangibles', 'v4_offer')
        data_hash['offer_period'] = offer_period
        data_hash['price_specification'] = [price_specification]
        data_hash
      end

      def price_specification
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('intangibles', 'v4_unit_price_specification')
        data_hash['validity_period'] = offer_period
        data_hash
      end

      def schedule
        {
          'start_time' => {
            'time' => 8.days.ago.to_s,
            'zone' => 'Vienna'
          },
          'duration' => 10.days.to_i
        }
      end

      def validity_period
        {
          'valid_from' => 10.days.ago,
          'valid_until' => 10.days.from_now
        }
      end

      def offer_period
        {
          'valid_from' => 10.days.ago,
          'valid_through' => 10.days.from_now
        }
      end
    end
  end
end
