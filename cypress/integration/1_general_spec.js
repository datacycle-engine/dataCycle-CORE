describe('General', function () {

  it('login', function () {
    cy.fixture('login_users').as('usersJSON').then(() => {
      cy.visit('/users/sign_in')
      const user = this.usersJSON['admin']

      cy.get('input#user_email:visible').type(user.email)
      cy.get('input#user_password:visible').type(user.password + '{enter}')

      cy.location('pathname').should('eq', '/')
      cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    })
  })

  it('logout', function () {
    cy.login('admin')

    cy.get('.show-sidebar').click()
    cy.get('.logout-link').click()
    cy.location('pathname').should('match', /\/users\/sign_in/)
  })
})
