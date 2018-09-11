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
    cy.visit('/').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')

    cy.get('.show-sidebar').click()
    cy.get('#settings-off-canvas .users-link').click()
    cy.location('pathname').should('match', /\/users/)

    cy.get('[data-toggle="new-object"]').click()
    cy.get('#new-object .option[data-open="new_data_cycle_core_user"]').click()

    cy.get('#new_data_cycle_core_user').should('be.visible')
    cy.get('#new_data_cycle_core_user input#user_email').type(user.email)
    cy.get('#new_data_cycle_core_user input#user_given_name').type('Der')
    cy.get('#new_data_cycle_core_user input#user_family_name').type('Tester')
    cy.get('#new_data_cycle_core_user input#user_password').type(user.password)
    cy.get('#new_data_cycle_core_user input#user_password_confirmation').type(user.password)
    cy.get('#new_data_cycle_core_user #user_role_id').select('Standard')
    cy.get('#new_data_cycle_core_user input[type="submit"]').click()
    cy.location('pathname').should('match', /\/users/)

    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + user.email + ')').should('have.length', 1)

    cy.testLogin(user).then((resp) => {
      expect(resp.status).to.eq(302)
    })
  })

  it('update', function () {
    cy.visit('/users').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + user.email + ')').should('have.length', 1).find('.edit-link').click()
    cy.location('pathname').should('match', /\/users\/.*\/edit/)

    cy.get('input#user_email').clear().type(updated_user.email)
    cy.get('input#user_password').clear().type(updated_user.password)
    cy.get('input#user_password_confirmation').clear().type(updated_user.password)
    cy.get('.submit-edit-form').click()
    cy.location('pathname').should('match', /\/users/)

    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.visit('/users')
    cy.get('.search-results .grid-item:contains(' + updated_user.email + ')').should('have.length', 1)

    cy.testLogin(updated_user).then((resp) => {
      expect(resp.status).to.eq(302)
    })
  })

  it('lock', function () {
    cy.visit('/users').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + updated_user.email + ')').should('have.length', 1).find('.lock-link').click()
    cy.location('pathname').should('match', /\/users/)

    cy.get('.confirmation-modal').should('be.visible').find('.confirmation-confirm').click()
    cy.location('pathname').should('match', /\/users/)
    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

    cy.testLogin(updated_user).then((resp) => {
      expect(resp.status).to.eq(302)
      expect(resp.redirectedToUrl).to.have.string('/users/sign_in')
    })
  })

  it('unlock', function () {
    cy.visit('/users').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + updated_user.email + ')').should('have.length', 1).find('.unlock-link').click()
    cy.location('pathname').should('match', /\/users/)
    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

    cy.testLogin(updated_user).then((resp) => {
      expect(resp.status).to.eq(302)
    })
  })
})
