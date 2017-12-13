describe('DataCycle', function () {
  it('Login', function () {
    cy.visit('localhost:3000')
    cy.get('#user_email').type('admin@pixelpoint.at')
    cy.get('#user_password').type('k2*8NTxhrU2VDXqH')
    cy.get('[type=submit]').click()
    cy.url().should('include', 'localhost:3000')
    cy.get('.flash.callout .close-button').click()
  })

  context('Watchlists', function () {
    beforeEach(function () {
      cy.visit('localhost:3000')
      cy.get('#user_email').type('admin@pixelpoint.at')
      cy.get('#user_password').type('k2*8NTxhrU2VDXqH')
      cy.get('[type=submit]').click()
      cy.url().should('include', 'localhost:3000')
      cy.get('.flash.callout .close-button').click()
    })

    it('can be created', function () {
      cy.get('#add-to-watchlist-link').click()
      cy.get('#header-menu_watch_list_headline').type('Merkliste 1').enter()
    })

  })
})
