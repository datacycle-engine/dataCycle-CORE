# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module Transformations
        def self.to_xml(external_system, content)
          @source = external_system.credentials.dig('xml', 'source')
          @owner =  external_system.credentials.dig('xml', 'owner')

          builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
            xml.pois('xmlns' => 'http://www.outdooractive.com/api/schema/alp.interface', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:schemaLocation' => 'http://www.outdooractive.com/api/schema/alp.interface alp.interface.pois.xsd') do
              xml.source @source
              xml.owner @owner
              xml.poi('id' => content.id, 'workflow' => 'online', 'lastmodified' => content.updated_at) do
                xml.owner @owner
                xml.author 'DataCycle'
                xml.point outdoor_active_point(content.location) if content.respond_to?(:location)
                outdoor_active_categories(content, xml)
                outdoor_active_contact(content, xml)
                outdoor_active_descriptons(content, xml)
                outdoor_active_images(content, xml)
              end
            end
          end
          builder.to_xml
        end

        def self.outdoor_active_point(location)
          "#{location.y} #{location.x}" if location.present?
        end

        def self.outdoor_active_contact(content, xml)
          xml.contact do
            if content.address.present?
              xml.address do
                xml.street content.address.try(:street_address)
                xml.postalcode content.address.try(:postal_code)
                xml.municipality content.address.try(:municipality)
                xml.number content.address.try(:number)
              end
            end
            xml.tel content.contact_info.try(:telephone)
            xml.fax content.contact_info.try(:fax_number)
            xml.email content.contact_info.try(:email)
            xml.url content.contact_info.try(:url)
          end
        end

        def self.outdoor_active_descriptons(content, xml)
          # TODO: missing Outdoor Active atttributes:
          # parking
          # getting_there
          # businessHours
          # fee

          xml.descriptions do
            content.translations.each do |translation|
              I18n.with_locale(translation.locale) do
                xml.description('lang' => translation.locale) do
                  xml.title content.name
                  xml.abstract ActionView::Base.full_sanitizer.sanitize(content.description) if content.description.present?
                  xml.text_ ActionView::Base.full_sanitizer.sanitize(content.text) if content.text.present?
                end
              end
            end
          end
          xml
        end

        def self.outdoor_active_images(content, xml)
          # TODO: missing:
          # point

          image_attributes = [:primary_image, :image, :logo]

          xml.images do
            image_attributes.each do |image_attribute|
              next if content.try(image_attribute).blank?
              content.try(image_attribute).each do |image|
                xml.image('id' => image.id, 'src' => image.content_url) do
                  image.translations.each do |translation|
                    I18n.with_locale(translation.locale) do
                      xml.description('lang' => translation.locale) do
                        xml.title image.name
                      end
                    end
                  end
                  xml.author image.try(:author)&.first&.name if image.try(:author).present?
                  image_license(image, xml)
                  xml.source @source
                end
              end
            end
          end
        end

        def self.image_license(image, xml)
          license_string = "#{(image.copyright_holder.present? ? image.copyright_holder&.first&.title : '')}#{(image.copyright_year.present? ? ', ' + image.copyright_year.to_s : '')}"
          return if license_string.blank?
          xml.license license_string
        end

        def self.outdoor_active_categories(content, xml)
          categories = DataCycleCore::Export::OutdoorActive::Functions.outdoor_active_categories(content)
          if categories.count == 1
            xml.category categories.first.external_key.split(':').last
          else
            xml.categories do
              categories.each do |category|
                xml.category category.external_key.split(':').last
              end
            end
          end
        end
      end
    end
  end
end
