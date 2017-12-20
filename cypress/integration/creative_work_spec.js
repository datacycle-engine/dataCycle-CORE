describe('CreativeWork', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const name = 'test_thema_' + Date.now()

  it('create thema', function () {
    cy.get('#search').type(name + '{enter}')
    cy.get('#new-object-circle').click()
    cy.get('#new-object .option').first().then(($elem) => {
      $elem.click()
      cy.get('#' + $elem.data('open')).find('form').submit()
      cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
      cy.get('.headline input[type=text]').should('have.value', name)
      cy.get('.edit-header-functions .discard').click()
      cy.get('.detail-header-wrapper').should(($elem) => {
        expect($elem.first()).to.contain(name)
      })
      cy.get('.content-pool-buttons .content-pool:contains(Aktuelle Inhalte)').click()
      cy.get('.content-pool-buttons span.content-pool:contains(Aktuelle Inhalte)').should('have.length', 1)
      cy.visit('/').get('#search').type(name + '{enter}').get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1)
    })
  })

  it('udpate thema', function () {
    cy.get('#search').type(name + '{enter}').get('.search-results .grid-item:contains(' + name + ') .content-link').click({
      force: true
    })
    const updated_name = name + '_updated'
    cy.get('.edit-content-link').click()
    cy.wait(1000)
    cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).type('{selectall}{del}').type(updated_name)
    cy.get('.submit-edit-form').click()
    cy.get('.headline input[type=text]').should('have.value', updated_name)
  })
})
