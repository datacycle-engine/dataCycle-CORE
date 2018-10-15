describe('Availability', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  // it('info', function () {
  //   cy.request({
  //     url: '/info',
  //     followRedirect: false
  //   }).then((response) => {
  //     expect(response.status).to.eq(200)
  //   })
  // })

  // it('admin', function () {
  //   cy.request({
  //     url: '/admin',
  //     followRedirect: false,
  //     failOnStatusCode: false
  //   }).then((response) => {
  //     expect(response.status).to.eq(403)
  //   })
  // })

  // it('settings', function () {
  //   cy.request({
  //     url: '/settings',
  //     followRedirect: false
  //   }).then((response) => {
  //     expect(response.status).to.eq(200)
  //   })
  // })

  it('classifications', function () {
    cy.request({
      url: '/classifications',
      followRedirect: false
    }).then((response) => {
      expect(response.status).to.eq(200)
    })
  })
})
