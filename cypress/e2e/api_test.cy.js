describe('Test API', () => {
  it('Checks API returns integer', () => {
    cy.request({
      method:'POST', 
      url: Cypress.env('API_URL') + '/visits?key=' + Cypress.env('API_KEY')
    })
    .then((response) => {
      expect(response.body).to.match(/^[0-9]*$/)
    })
  })

  it('Checks counter increments', () => {
    cy.request({
      method:'POST', 
      url: Cypress.env('API_URL') + '/visits?key=' + Cypress.env('API_KEY')
    })
    .then((response) =>{
      let count = Number(response.body);
      cy.wrap(count).as('count')
    })

    cy.request({
      method:'POST', 
      url: Cypress.env('API_URL') + '/visits?key=' + Cypress.env('API_KEY')
    })
    .then((response) =>{
      let new_count = Number(response.body);
      cy.wrap(new_count).as('new_count')
    })

    cy.get('@count').then(count => {
      cy.get('@new_count').should('be.gt', count);
    })
  })

  it('Tries GET and fails (405)', () => {
    cy.request({
      method: 'GET', 
      url: Cypress.env('API_URL') + '/visits?key=' + Cypress.env('API_KEY'),
      failOnStatusCode: false,
    })
      .then((response) => {
      expect(response.status).to.eq(405)
    })
  })

  it('Tries without key and fails (401)', () => {
    cy.request({
      method: 'POST', 
      url: Cypress.env('API_URL') + '/visits',
      failOnStatusCode: false,
    })
      .then((response) => {
      expect(response.status).to.eq(401)
    })
  })

  it('Tries bad key and fails (400)', () => {
    cy.request({
      method: 'POST', 
      url: Cypress.env('API_URL') + '/visits?key=wrongapikey',
      failOnStatusCode: false,
    })
      .then((response) => {
      expect(response.status).to.eq(400)
    })
  })

  it('Tries invalid route and fails (404)', () => {
    cy.request({
      method: 'POST', 
      url: Cypress.env('API_URL') + '/home?key=' + Cypress.env('API_KEY'),
      failOnStatusCode: false,
    })
      .then((response) => {
      expect(response.status).to.eq(404)
    })
  })

  it('Tries no route and fails (404)', () => {
    cy.request({
      method: 'POST', 
      url: Cypress.env('API_URL') + '?key=' + Cypress.env('API_KEY'),
      failOnStatusCode: false,
    })
      .then((response) => {
      expect(response.status).to.eq(404)
    })
  })

})