describe('General', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  it('test logout', function () {
    cy.get('.show-sidebar').click()
    cy.get('.logout-link').click()
    cy.url().should('contain', '/users/sign_in')
  })

})
