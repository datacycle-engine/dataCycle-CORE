describe('General', function () {

  it('login', function () {
    cy.fixture('login_users').as('usersJSON').then(() => {
      cy.visit('/users/sign_in')
      var authenticity_token = ""
      cy.get('input[name=authenticity_token]').then(($elem) => {
        authenticity_token = $elem.val()
        const user = this.usersJSON['admin']

        cy.get('input#user_email:visible').type(user.email)
        cy.get('input#user_password:visible').type(user.password + '{enter}')

        cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

        cy.location().should((loc) => {
          expect(loc.pathname).to.eq('/')
        })
      })
    })
  })

  it('logout', function () {
    cy.login('admin')

    cy.get('.show-sidebar').click()
    cy.get('.logout-link').click()
    cy.location().should((loc) => {
      expect(loc.pathname).to.eq('/users/sign_in')
    })
  })
})
