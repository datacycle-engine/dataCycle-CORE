describe('Subscription', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const option = 'Artikel'
  const cname = 'Test_' + option + '_' + Date.now()

  it('create', function () {
    cy.createCreativeWork(cname, option)
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('#search').type(cname + '{enter}', {
      force: true
    }).get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).click()

    cy.get('.detail-header-functions [data-toggle="subscribe"]').click()
    cy.get('#subscribe').should('be.visible').find('a').click()

    cy.get('.user-subscriptions-link').click()
    cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1)
  })

  it('remove', function () {
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('#search').type(cname + '{enter}', {
      force: true
    }).get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).click()

    cy.get('.detail-header-functions [data-toggle="subscribe"]').click()
    cy.get('#subscribe').should('be.visible').find('a[data-method="delete"]').click()

    cy.get('.user-subscriptions-link').click()
    cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 0)
  })
})
