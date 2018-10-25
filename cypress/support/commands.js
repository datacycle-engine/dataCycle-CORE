Cypress.Commands.overwrite('type', (originalFn, jquery_object, text, options) => {
  options = Object.assign({
    force: true,
    delay: 0
  }, options)
  return originalFn(jquery_object, text, options)
})

Cypress.Commands.add('login', function (userType, options = {}) {
  cy.fixture('login_users').as('usersJSON').then(() => {
    const user = this.usersJSON[userType]

    cy.request({
      url: '/users/sign_in',
      method: 'POST',
      body: {
        utf8: "✓",
        user: {
          email: user.email,
          password: user.password,
          remember_me: 0
        }
      },
      failOnStatusCode: false,
      followRedirect: false
    })
  })
})

Cypress.Commands.add('logout', function () {
  cy.request({
    url: '/users/sign_out',
    method: 'DELETE',
    body: {
      utf8: "✓"
    },
    failOnStatusCode: false,
    followRedirect: false
  })
})

Cypress.Commands.add('testLogin', function (user) {
  cy.logout()

  cy.request({
    url: '/users/sign_in',
    method: 'POST',
    body: {
      utf8: "✓",
      user: {
        email: user.email,
        password: user.password,
        remember_me: 0
      }
    },
    failOnStatusCode: false,
    followRedirect: false
  })
})

Cypress.Commands.add('createThing', function (name, template) {
  cy.request({
    url: '/things',
    method: 'POST',
    body: {
      utf8: "✓",
      template: template,
      thing: {
        datahash: {
          headline: name
        }
      }
    },
    failOnStatusCode: false,
    followRedirect: false
  })
})

Cypress.Commands.add('createUser', function (user, template) {
  cy.request({
    url: '/users/create_user',
    method: 'POST',
    body: {
      utf8: "✓",
      user: user
    },
    failOnStatusCode: false,
    followRedirect: false
  })
})

Cypress.Commands.add('createUserGroup', function (name, template) {
  cy.request({
    url: '/user_groups',
    method: 'POST',
    body: {
      utf8: "✓",
      user_group: {
        name: name
      }
    },
    failOnStatusCode: false,
    followRedirect: false
  })
})
