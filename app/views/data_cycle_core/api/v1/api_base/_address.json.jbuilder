# frozen_string_literal: true

json.set! '@type', 'PostalAddress'
json.set! 'streetAddress', addressData.street_address if addressData.street_address.present?
json.set! 'postalCode', addressData.postal_code if addressData.postal_code.present?
json.set! 'addressLocality', addressData.address_locality if addressData.address_locality.present?
json.set! 'addressCountry', addressData.address_country if addressData.address_country.present?
