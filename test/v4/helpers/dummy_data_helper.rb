# frozen_string_literal: true

module DataCycleCore
  module V4
    module DummyDataHelper
      module_function

      # TODO: add classifications more generic
      def create_data(type, user = nil)
        raise ArgumentError, "Unknown type (#{type}) for DummyDataHelper" unless respond_to?(type)

        @user = user
        send(type)
      end

      def minimal_poi
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'v4_poi')
        data_hash['name'] = "poi_#{SecureRandom.uuid}"
        data_hash['validity_period'] = validity_period
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('country_code').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Ländercodes').with_name(data_hash['country_code'])
          data_hash['country_code'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: data_hash, user: @user)
      end

      def poi
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'v4_poi')
        data_hash['name'] = "poi_#{SecureRandom.uuid}"
        data_hash['validity_period'] = validity_period
        data_hash['image'] = [image.id]
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('country_code').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Ländercodes').with_name(data_hash['country_code'])
          data_hash['country_code'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: data_hash, user: @user)
      end

      def full_poi
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'v4_poi')
        data_hash['name'] = "poi_#{SecureRandom.uuid}"
        data_hash['validity_period'] = validity_period
        image_id = image.id
        data_hash['image'] = [image_id]
        data_hash['logo'] = [image_id]
        data_hash['primary_image'] = [image_id]
        data_hash[:opening_hours_specification] = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_specification')
        data_hash[:opening_hours_description] = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_description')
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('country_code').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Ländercodes').with_name(data_hash['country_code'])
          data_hash['country_code'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
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
        # TODO: make this more generic for all kind of classifications
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('tags').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name(data_hash['tags'])
          data_hash['tags'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data_hash, user: @user)
      end

      def video
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('media_objects', 'v4_video')
        data_hash['name'] = "video_#{SecureRandom.uuid}"
        # TODO: make this more generic for all kind of classifications
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('tags').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name(data_hash['tags'])
          data_hash['tags'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'Video', data_hash: data_hash, user: @user)
      end

      def full_image
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('media_objects', 'v4_image')
        data_hash['name'] = "image_#{SecureRandom.uuid}"
        data_hash['author'] = [person.id]
        data_hash['copyright_holder'] = [organization.id]
        data_hash['content_location'] = [poi.id]
        # TODO: make this more generic for all kind of classifications
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('tags').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name(data_hash['tags'])
          data_hash['tags'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        data_hash['validity_period'] = validity_period
        data_hash['asset'] = upload_image

        DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data_hash, user: @user)
      end

      def event
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'v4_event')
        data_hash['event_schedule'] = [schedule]
        data_hash['validity_period'] = validity_period
        data_hash['offers'] = [offer]
        data_hash['image'] = [full_image.id]
        data_hash['organizer'] = [person.id]
        data_hash['performer'] = [organization.id]
        data_hash['content_location'] = [poi.id]
        data_hash['super_event'] = [event_series.id]
        # TODO: add more generic way
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('event_attendance_mode').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Veranstaltungsteilnahmemodus').with_name(data_hash['event_attendance_mode'])
          data_hash['event_attendance_mode'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('event_status').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Veranstaltungsstatus').with_name(data_hash['event_status'])
          data_hash['event_status'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: data_hash, user: @user)
      end

      def event_series
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'v4_event_series')
        data_hash['image'] = [image.id]
        data_hash['validity_period'] = validity_period
        data_hash['organizer'] = [organization.id]
        data_hash['performer'] = [person.id]
        data_hash['content_location'] = [poi.id]
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('event_attendance_mode').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Veranstaltungsteilnahmemodus').with_name(data_hash['event_attendance_mode'])
          data_hash['event_attendance_mode'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('event_status').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Veranstaltungsstatus').with_name(data_hash['event_status'])
          data_hash['event_status'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'Eventserie', data_hash: data_hash, user: @user)
      end

      def minimal_event
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'v4_event_minimal')
        data_hash['name'] = "event_#{SecureRandom.uuid}"
        data_hash['event_schedule'] = [schedule]
        data_hash['validity_period'] = validity_period
        DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: data_hash, user: @user)
      end

      def article
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'v4_article')
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('tags').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name(data_hash['tags'])
          data_hash['tags'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        data_hash['image'] = [image.id]
        data_hash['video'] = [image.id]
        data_hash['author'] = [person.id]
        data_hash['validity_period'] = validity_period
        data_hash['content_location'] = [poi.id]
        DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: data_hash, user: @user)
      end

      def structured_article
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'v4_structured_article')
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('tags').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name(data_hash['tags'])
          data_hash['tags'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        data_hash['image'] = [image.id]
        data_hash['video'] = [image.id]
        data_hash['author'] = [person.id]
        data_hash['validity_period'] = validity_period
        data_hash['content_location'] = [poi.id]
        data_hash['content_block'] = [content_block]
        DataCycleCore::TestPreparations.create_content(template_name: 'Strukturierter Artikel', data_hash: data_hash, user: @user)
      end

      def person
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person')
        if data_hash.dig('country_code').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Ländercodes').with_name(data_hash['country_code'])
          data_hash['country_code'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        data_hash['member_of'] = [organization.id]
        data_hash['image'] = [image.id]
        DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: data_hash, user: @user)
      end

      def minimal_person
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person')
        if data_hash.dig('country_code').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Ländercodes').with_name(data_hash['country_code'])
          data_hash['country_code'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: data_hash, user: @user)
      end

      def person_overlay
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_overlay')
        if data_hash.dig('country_code').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Ländercodes').with_name(data_hash['country_code'])
          data_hash['country_code'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        data_hash['image'] = [image.id]
        DataCycleCore::TestPreparations.create_content(template_name: 'PersonOverlay', data_hash: data_hash, user: @user)
      end

      def person_overlay_minimal
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_overlay_minimal')
        data_hash['image'] = [image.id]
        DataCycleCore::TestPreparations.create_content(template_name: 'PersonOverlay', data_hash: data_hash, user: @user)
      end

      def organization
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('organizations', 'v4_organization')
        data_hash['image'] = [image.id]
        data_hash['content_location'] = [poi.id]
        if data_hash.dig('country_code').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Ländercodes').with_name(data_hash['country_code'])
          data_hash['country_code'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        if data_hash.dig('license_classification').present?
          classification_alias = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(data_hash['license_classification'])
          data_hash['license_classification'] = classification_alias.map { |c| c.primary_classification.id } if classification_alias.present?
        end
        DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: data_hash, user: @user)
      end

      def offer
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('intangibles', 'v4_offer')
        data_hash['offer_period'] = offer_period
        data_hash['price_specification'] = [price_specification]
        data_hash['offered_by'] = [person.id]
        data_hash['item_offered'] = [service.id]
        data_hash
      end

      def service
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('intangibles', 'v4_service')
        data_hash['hours_available'] = [schedule]
        DataCycleCore::TestPreparations.create_content(template_name: 'Service', data_hash: data_hash, user: @user)
      end

      def price_specification
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('intangibles', 'v4_unit_price_specification')
        data_hash['validity_period'] = offer_period
        data_hash
      end

      def content_block
        data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'v4_content_block')
        data_hash['image'] = image.id
        data_hash
      end

      def schedule
        {
          'start_time' => {
            'time' => 8.days.ago.to_s,
            'zone' => 'Europe/Vienna'
          },
          'duration' => 10.days.to_i
        }
      end

      def validity_period
        {
          'valid_from' => 10.days.ago.to_date,
          'valid_until' => 10.days.from_now.to_date
        }
      end

      def offer_period
        {
          'valid_from' => 10.days.ago.to_date,
          'valid_through' => 10.days.from_now.to_date
        }
      end

      def upload_image
        file_name = 'test_rgb.jpeg'
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        @image = DataCycleCore::Image.new
        @image.file.attach(io: File.open(file_path), filename: file_name)
        @image.save
        @image.reload
        [@image]
      end
    end
  end
end
