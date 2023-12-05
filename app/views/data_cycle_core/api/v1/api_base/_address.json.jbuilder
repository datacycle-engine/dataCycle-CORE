# frozen_string_literal: true

json.set! '@type', 'PostalAddress'
json.set! 'streetAddress', addressData.street_address if addressData.try(:street_address).present?
json.set! 'postalCode', addressData.postal_code if addressData.try(:postal_code).present?
json.set! 'addressLocality', addressData.address_locality if addressData.try(:address_locality).present?
json.set! 'addressCountry', addressData.address_country if addressData.try(:address_country).present?
