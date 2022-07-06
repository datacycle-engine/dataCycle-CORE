# frozen_string_literal: true

module DataCycleCore
  module DummyDataHelper
    module_function

    def create_data(type, user = nil)
      @user = user
      send(type)
    rescue StandardError => e
      raise ArgumentError, "Unknown type (#{type}) for DummyDataHelper: #{e.message}"
    end

    def tour
      # schedule
      schedule = [
        {
          by_month: (['Juni'].map { |m| DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Monate', m) })
        }
      ]

      poi_data = poi
      image_data = image

      tour_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_tour')
      tour_data_hash[:image] = image_data.id
      tour_data_hash[:primary_image] = image_data.id
      tour_data_hash[:logo] = image_data.id
      tour_data_hash[:poi] = poi_data.id
      tour_data_hash[:schedule] = schedule
      tour_data_hash.deep_stringify_keys!

      content = DataCycleCore::Thing.find_by(tour_data_hash.slice('name').merge(template_name: 'Tour'))
      return @content if @content.present?

      content = DataCycleCore::Thing.find_by(template_name: 'Tour', template: true).dup
      content.template = false
      content.created_by = @user&.id
      content.external_key = 'test1'
      content.external_source_id = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system').id

      content.save!
      I18n.with_locale(:de) do
        content.set_data_hash(data_hash: tour_data_hash, new_content: true, current_user: @user)
      end
      content.reload
    end

    def poi
      DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: generate_poi_data_hash, user: @user)
    end

    def poi_translated
      content = poi
      I18n.with_locale(:en) { content.set_data_hash(data_hash: generate_poi_data_hash) }
      content
    end

    def generate_poi_data_hash
      image_data = image

      poi_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', "api_poi_#{I18n.locale}")
      country_classification = DataCycleCore::Classification.find_by(name: 'AT', description: 'Österreich')
      poi_data_hash[:country_code] = [country_classification.id]
      poi_data_hash[:image] = image_data.id
      poi_data_hash[:primary_image] = image_data.id
      poi_data_hash[:logo] = image_data.id

      poi_data_hash[:opening_hours_specification] = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_specification')
      poi_data_hash[:opening_hours_description] = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_description')
      poi_data_hash
    end

    def poi1
      poi_data_hash = process_poi1_data_hash(DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'poi1_de'))
      content = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: poi_data_hash, user: @user)
      I18n.with_locale(:en) { content.set_data_hash(data_hash: process_poi1_data_hash(DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'poi1_en'))) }
      content
    end

    def process_poi1_data_hash(hash)
      hash['additional_information'] = hash['additional_information']
        .sort_by { |a| a['name'] }
        .zip(
          [
            DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', 'description'),
            DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', 'parking')
          ]
        ).map { |data, classification| data.merge('universal_classifications' => Array.wrap(classification)) }
      hash
    end

    def bergfex_snowresort
      snow_resort_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_bergfex_snowresort')

      snow_resort_data_hash[:opening_hours_specification] = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_specification')
      snow_resort_data_hash[:opening_hours_description] = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'opening_hours_description')

      DataCycleCore::TestPreparations.create_content(template_name: 'Skigebiet', data_hash: snow_resort_data_hash, user: @user)
    end

    def person
      person_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'api_person')
      gender_classification = DataCycleCore::Classification.find_by(name: 'Männlich')
      country_classification = DataCycleCore::Classification.find_by(name: 'AT', description: 'Österreich')
      person_data_hash[:gender] = [gender_classification.id]
      person_data_hash[:country_code] = [country_classification.id]
      person_data_hash[:image] = [image.id]
      DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: person_data_hash, user: @user)
    end

    def organization
      organization_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('organizations', 'api_organization')
      country_classification = DataCycleCore::Classification.find_by(name: 'AT', description: 'Österreich')
      organization_data_hash[:country_code] = [country_classification.id]
      organization_data_hash[:image] = [image.id]
      DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: organization_data_hash, user: @user)
    end

    def event
      event_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('events', 'api_event')
      event_data_hash[:image] = [image.id]
      event_data_hash[:content_location] = [poi.id]
      DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: event_data_hash, user: @user)
    end

    def article
      DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: creative_work_dummy_hash('api_article'), user: @user)
    end

    def biography
      DataCycleCore::TestPreparations.create_content(template_name: 'Biografie', data_hash: creative_work_dummy_hash('api_article'), user: @user)
    end

    def interview
      DataCycleCore::TestPreparations.create_content(template_name: 'Interview', data_hash: creative_work_dummy_hash('api_article'), user: @user)
    end

    def quiz
      DataCycleCore::TestPreparations.create_content(template_name: 'Quiz', data_hash: creative_work_dummy_hash('api_quiz'), user: @user)
    end

    def social_media_posting
      DataCycleCore::TestPreparations.create_content(template_name: 'SocialMediaPosting', data_hash: creative_work_dummy_hash('api_article'), user: @user)
    end

    def timeline
      DataCycleCore::TestPreparations.create_content(template_name: 'Zeitleiste', data_hash: creative_work_dummy_hash('api_timeline'), user: @user)
    end

    def recipe
      recipe_data_hash = creative_work_dummy_hash('api_recipe')
      recipe_category = DataCycleCore::Classification.find_by(name: 'Rezept-Kategorie 1')
      recipe_data_hash[:recipe_category] = [recipe_category.id]
      recipe_course = DataCycleCore::Classification.find_by(name: 'Rezept-Gang 1')
      recipe_data_hash[:recipe_course] = [recipe_course.id]

      DataCycleCore::TestPreparations.create_content(template_name: 'Rezept', data_hash: recipe_data_hash, user: @user)
    end

    def image
      image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
      DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash, user: @user)
    end

    def asset
      asset_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_asset')
      DataCycleCore::TestPreparations.create_content(template_name: 'Datei', data_hash: asset_data_hash, user: @user)
    end

    def audio
      audio_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_audio')
      DataCycleCore::TestPreparations.create_content(template_name: 'Audio', data_hash: audio_data_hash, user: @user)
    end

    def pdf
      pdf_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_pdf')
      DataCycleCore::TestPreparations.create_content(template_name: 'PDF', data_hash: pdf_data_hash, user: @user)
    end

    def video
      video_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_video')
      DataCycleCore::TestPreparations.create_content(template_name: 'Video', data_hash: video_data_hash, user: @user)
    end

    def container
      container_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_container')
      DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: container_data_hash, user: @user)
    end

    def creative_work_dummy_hash(fixture_name)
      creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', fixture_name)
      creative_work_data_hash[:author] = person.id
      creative_work_data_hash[:about] = organization.id
      creative_work_data_hash[:image] = image.id
      creative_work_data_hash[:content_location] = poi.id
      tag_classification = DataCycleCore::Classification.find_by(name: 'Tag 1')
      creative_work_data_hash[:tags] = [tag_classification.id]
      creative_work_data_hash[:validity_period] = validity_period
      creative_work_data_hash
    end

    def additional_property
      ap_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_additional_property')
      DataCycleCore::TestPreparations.create_content(template_name: 'Additional-Property-Creative-Work', data_hash: ap_data_hash, user: @user)
    end

    def validity_period
      {
        'valid_from' => 10.days.ago.to_date,
        'valid_until' => 10.days.from_now.to_date
      }
    end
  end
end
