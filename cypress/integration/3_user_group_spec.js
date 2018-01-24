describe('UserGroup', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const name = 'Test_UserGroup_' + Date.now()
  const updated_name = 'Updated_' + name
  const user = {
    email: 'test_user_' + Date.now() + '@tester.com',
    given_name: 'Test_' + Date.now(),
    family_name: 'Test_' + Date.now(),
    password: 'test_password',
    password_confirmation: 'test_password'
  }


  it('create', function () {
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('.show-sidebar').click()
    cy.get('#settings-off-canvas .user-groups-link').click()

    cy.get('[data-toggle="new-object"]').click()
    cy.get('#new-object .option').click()

    cy.get('#new_user_group').should('be.visible')
    cy.get('#new_user_group input#user_group_name').type(name)
    cy.get('#new_user_group input[type="submit"]').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

    cy.get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1)
  })

  it('update', function () {
    cy.visit('/user_groups').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1).find('.edit-link').click()
    cy.get('input#user_group_name').clear().type(updated_name)
    cy.get('.submit-edit-form').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

    cy.visit('/user_groups')
    cy.get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 1)
  })

  it('delete', function () {
    cy.visit('/user_groups').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 1).find('.delete-link').click()
    cy.get('.confirmation').should('be.visible').find('.accept-confirmation').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

    cy.get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 0)
  })

  it('add user', function () {
    cy.createUser(user)
    cy.createUserGroup(name)
    cy.visit('/user_groups').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1).find('.edit-link').click()
    cy.get('#user_group_user_ids_').should('have.length', 1).siblings('.select2').find('input.select2-search__field').type(user.given_name + ' ' + user.family_name + '{enter}')
    cy.get('.submit-edit-form').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

    cy.visit('/users')
    cy.get('.search-results .grid-item:contains(' + user.email + ')').should('have.length', 1).find('.edit-link').click()
    cy.get('#user_user_group_ids_').should('have.length', 1).siblings('.select2').should(($elem) => {
      expect($elem.first()).to.contain(name)
    })
  })

})
