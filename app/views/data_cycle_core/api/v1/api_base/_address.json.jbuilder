json.set! '@type', 'PostalAddress'
json.set! 'streetAddress', object.streetAddress if object.streetAddress
json.set! 'postalCode', object.postalCode if object.postalCode
json.set! 'addressLocality', object.addressLocality if object.addressLocality
json.set! 'addressCountry', object.addressCountry if object.addressCountry
