describe('Object Browser', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const option = 'Artikel'
  const cname = 'Test_' + option + '_' + Date.now()
  const place = 'Test_place_' + Date.now()
  var id = undefined

  it('create and select place in Objectbrowser', function () {
    cy.createCreativeWork(cname, option).then(resp => {
      var url = resp.headers.location
      id = url.substr(url.indexOf('creative_works/') + 15, 36)
      cy.visit(url).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')

      cy.get('.object-browser[data-type="Örtlichkeit"]').should('be.visible').find('.button.show-objectbrowser').should('be.visible').click()
      cy.get('.object-browser-overlay:visible').should('be.visible').find('.new-item-button').should('be.visible').click()
      cy.get('.new-item:visible').should('be.visible').find('#place_datahash_name').should('be.visible').type(place + '{enter}')
      cy.get('.chosen-items:visible').should('be.visible').contains(place).should('have.length', 1)
      cy.get('.object-browser-search:visible').should('be.visible').type(place + '{enter}')
      cy.get('.items:not(.chosen-items):visible').contains(place).should('have.length', 1)

      cy.get('.save-object-browser:visible').should('be.visible').click()
      cy.get('.object-browser[data-type="Örtlichkeit"]').contains(place).should('have.length', 1)

      cy.get('.submit-edit-form').should('be.visible').click()
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
      cy.get('.detail-content-wrapper').contains(place).should('have.length', 1)
    })
  })

  it('deselect place', function () {
    cy.visit('/creative_works/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.object-browser[data-type="Örtlichkeit"]').should('be.visible').contains(place).should('have.length', 1).closest('.item').find('.delete-thumbnail').should('be.visible').click()

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(place).should('have.length', 0)
  })

  it('select place in Objectbrowser', function () {
    cy.visit('/creative_works/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.object-browser[data-type="Örtlichkeit"]').should('be.visible').find('.button.show-objectbrowser').should('be.visible').click()

    cy.get('.object-browser-search:visible').should('be.visible').type(place + '{enter}')
    cy.get('.items:not(.chosen-items):visible .item:contains(' + place + ')').should('have.length', 1).should('be.visible').trigger('click')

    cy.get('.chosen-items:visible').should('be.visible').contains(place).should('have.length', 1)
    cy.get('.save-object-browser:visible').should('be.visible').click()
    cy.get('.object-browser[data-type="Örtlichkeit"]').contains(place).should('have.length', 1)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(place).should('have.length', 1)
  })

  it('deselect place in Objectbrowser', function () {
    cy.visit('/creative_works/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.object-browser[data-type="Örtlichkeit"]').should('be.visible').find('.button.show-objectbrowser').should('be.visible').click()

    cy.get('.object-browser-search:visible').should('be.visible').type(place + '{enter}')
    cy.get('.items:not(.chosen-items):visible .item:contains(' + place + ')').should('have.length', 1).should('be.visible').trigger('click')

    cy.get('.chosen-items:visible').should('be.visible').contains(place).should('have.length', 0)
    cy.get('.save-object-browser:visible').should('be.visible').click()
    cy.get('.object-browser[data-type="Örtlichkeit"]').contains(place).should('have.length', 0)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(place).should('have.length', 0)
  })

})
