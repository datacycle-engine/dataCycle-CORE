describe('CreativeWork', function () {
  beforeEach(function () {
    cy.login('admin')
  })


  it('create a thema', function () {
    const name = 'test_thema_' + Date.now()
    cy.get('#search').type(name)

    // cy.visit('localhost:3000')
  })
})
