describe('User', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const user = {
    email: 'test_user_' + Date.now() + '@tester.com',
    password: 'password_' + Date.now()
  }

  const updated_user = {
    email: 'updated_' + user.email,
    password: 'updated_password_' + Date.now()
  }

  it('create', function () {
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })

    cy.get('.show-sidebar').click()
    cy.get('#settings-off-canvas .users-link').click()

    cy.get('[data-toggle="new-object"]').click()
    cy.get('#new-object .option').click()

    cy.get('#new_user').should('be.visible')
    cy.get('#new_user input#user_email').type(user.email)
    cy.get('#new_user input#user_given_name').type('Der')
    cy.get('#new_user input#user_family_name').type('Tester')
    cy.get('#new_user input#user_password').type(user.password)
    cy.get('#new_user input#user_password_confirmation').type(user.password)
    cy.get('#new_user input[type="submit"]').click()

    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
    cy.get('.search-results .grid-item:contains(' + user.email + ')').should('have.length', 1)

    cy.testLogin(user).then((resp) => {
      expect(resp.status).to.eq(302)
    })
  })

  it('update', function () {
    cy.visit('/users').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('.search-results .grid-item:contains(' + user.email + ')').should('have.length', 1).find('.edit-link').click()
    cy.get('input#user_email').clear().type(updated_user.email)
    cy.get('input#user_password').clear().type(updated_user.password)
    cy.get('input#user_password_confirmation').clear().type(updated_user.password)
    cy.get('.submit-edit-form').click()

    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
    cy.visit('/users')
    cy.get('.search-results .grid-item:contains(' + updated_user.email + ')').should('have.length', 1)

    cy.testLogin(updated_user).then((resp) => {
      expect(resp.status).to.eq(302)
    })
  })

  it('lock', function () {
    cy.visit('/users').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('.search-results .grid-item:contains(' + updated_user.email + ')').should('have.length', 1).find('.lock-link').click()
    cy.get('.confirmation').should('be.visible').find('.accept-confirmation').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

    cy.testLogin(updated_user).then((resp) => {
      expect(resp.status).to.eq(302)
      expect(resp.redirectedToUrl).to.have.string('/users/sign_in')
    })
  })

  it('unlock', function () {
    cy.visit('/users').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('.search-results .grid-item:contains(' + updated_user.email + ')').should('have.length', 1).find('.unlock-link').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

    cy.testLogin(updated_user).then((resp) => {
      expect(resp.status).to.eq(302)
    })
  })
})
