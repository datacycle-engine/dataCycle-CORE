describe('Subscription', function () {
  // beforeEach(function () {
  //   cy.login('admin')
  // })

  // const option = 'Artikel'
  // const cname = 'Test_' + option + '_' + Date.now()
  // var id = undefined

  // it('create', function () {
  //   cy.createCreativeWork(cname, option).then(resp => {
  //     var url = resp.headers.location.replace('/edit', '')
  //     id = url.substring(url.lastIndexOf('/') + 1)
  //     cy.visit(url).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
  //     cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

  //     cy.get('.detail-header-functions [data-toggle="subscribe"]').click()
  //     cy.get('#subscribe').should('be.visible').find('a').click()

  //     cy.get('.show-sidebar').click()
  //     cy.get('.user-subscriptions-link').should('be.visible').click()
  //     cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1)
  //   })
  // })

  // it('remove', function () {
  //   cy.visit('/creative_works/' + id).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
  //   cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

  //   cy.get('.detail-header-functions [data-toggle="subscribe"]').click()
  //   cy.get('#subscribe').should('be.visible').find('a[data-method="delete"]').click()

  //   cy.get('.show-sidebar').click()
  //   cy.get('.user-subscriptions-link').should('be.visible').click()

  //   cy.location('pathname').should('match', /\/subscriptions/)
  //   cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 0)
  // })
})
