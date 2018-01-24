describe('Subscription', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const option = 'Artikel'
  const cname = 'Test_' + option + '_' + Date.now()

  it('create', function () {
    cy.createCreativeWork(cname, option)
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.detail-header-functions [data-toggle="subscribe"]').click()
    cy.get('#subscribe').should('be.visible').find('a').click()

    cy.get('.user-subscriptions-link').click()
    cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1)
  })

  it('remove', function () {
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.detail-header-functions [data-toggle="subscribe"]').click()
    cy.get('#subscribe').should('be.visible').find('a[data-method="delete"]').click()

    cy.get('.user-subscriptions-link').click()
    cy.location('pathname').should('match', /\/subscriptions/)

    cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 0)
  })
})
