// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
//
// -- This is a parent command --
// Cypress.Commands.add("login", (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add("drag", { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add("dismiss", { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This is will overwrite an existing command --
// Cypress.Commands.overwrite("visit", (originalFn, url, options) => { ... })
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

Cypress.Commands.add('createCreativeWork', function (name, template) {
  cy.request({
    url: '/creative_works',
    method: 'POST',
    body: {
      utf8: "✓",
      template: template,
      creative_work: {
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
