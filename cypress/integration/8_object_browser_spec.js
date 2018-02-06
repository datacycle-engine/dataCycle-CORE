describe('ObjectBrowser', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const option = 'Artikel'
  const cname = 'Test_' + option + '_' + Date.now()
  const place = 'Test_place_' + Date.now()

  it('create and select place in Objectbrowser', function () {
    cy.createCreativeWork(cname, option).then(resp => {
      var url = resp.headers.location
      cy.visit(url).get('.flash.callout .close-button').click({
        force: true
      }).should('be.hidden')

      cy.get('.object-browser[data-type="place"]').should('be.visible').find('.button#show').should('be.visible').click()
      cy.get('.object-browser-overlay:visible').should('be.visible').find('.new-item-button').should('be.visible').click()
      cy.get('.new-item:visible').should('be.visible').find('#place_datahash_name').should('be.visible').type(place + '{enter}')
      cy.get('.chosen-items:visible').should('be.visible').contains(place).should('have.length', 1)
      cy.get('.object-browser-search:visible').should('be.visible').type(place + '{enter}')
      cy.get('.items:not(.chosen-items):visible').contains(place).should('have.length', 1)

      cy.get('.save-object-browser:visible').should('be.visible').click()
      cy.get('.object-browser[data-type="place"]').contains(place).should('have.length', 1)

      cy.get('.submit-edit-form').should('be.visible').click()
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
      cy.get('.detail-content-wrapper').contains(place).should('have.length', 1)
    })
  })

  it('deselect place', function () {
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ') .content-link').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.edit-content-link').click()
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.object-browser[data-type="place"]').should('be.visible').contains(place).should('have.length', 1).closest('.item').find('.delete-thumbnail').should('be.visible').click()

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(place).should('have.length', 0)
  })

  it('select place in Objectbrowser', function () {
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ') .content-link').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.edit-content-link').click()
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.object-browser[data-type="place"]').should('be.visible').find('.button#show').should('be.visible').click()

    cy.get('.object-browser-search:visible').should('be.visible').type(place + '{enter}')
    cy.get('.items:not(.chosen-items):visible .item:contains(' + place + ')').should('have.length', 1).should('be.visible').trigger('click')

    cy.get('.chosen-items:visible').should('be.visible').contains(place).should('have.length', 1)
    cy.get('.save-object-browser:visible').should('be.visible').click()
    cy.get('.object-browser[data-type="place"]').contains(place).should('have.length', 1)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(place).should('have.length', 1)
  })

  it('deselect place in Objectbrowser', function () {
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ') .content-link').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.edit-content-link').click()
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.object-browser[data-type="place"]').should('be.visible').find('.button#show').should('be.visible').click()

    cy.get('.object-browser-search:visible').should('be.visible').type(place + '{enter}')
    cy.get('.items:not(.chosen-items):visible .item:contains(' + place + ')').should('have.length', 1).should('be.visible').trigger('click')

    cy.get('.chosen-items:visible').should('be.visible').contains(place).should('have.length', 0)
    cy.get('.save-object-browser:visible').should('be.visible').click()
    cy.get('.object-browser[data-type="place"]').contains(place).should('have.length', 0)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(place).should('have.length', 0)
  })

})
