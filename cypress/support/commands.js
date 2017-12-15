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
    cy.visit('/users/sign_in')
    var authenticity_token = ""
    cy.get('input[name=authenticity_token]').then(($elem) => {
      authenticity_token = $elem.val()
      const user = this.usersJSON[userType]

      cy.request({
        url: '/users/sign_in',
        method: 'POST',
        body: {
          utf8: "✓",
          authenticity_token: authenticity_token,
          user: {
            email: user.email,
            password: user.password,
            remember_me: 0
          }
        },
        followRedirect: false
      })
      cy.visit('/')
    })
  })
})
