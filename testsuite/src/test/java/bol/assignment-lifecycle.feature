Feature: Assign, list and unassign a license

  Extends the core flow with the optional endpoints /v1/assignments/delete and
  /v1/users/licenses. Values from earlier responses (clientOrderLineId, licenseKeys)
  are used in later requests, and the result of each step is verified by querying
  the service provider with /v1/users/licenses.

  Background:
    * requireCapability('assignmentDelete')
    * requireCapability('userLicenses')
    * url baseUrl
    * def newOrder = read('classpath:bol/common/new-order.js')
    * def placeOrder = function(order){ return karate.call('classpath:bol/common/place-order.feature', { order: order }) }
    * def uuid = function(){ return java.util.UUID.randomUUID() + '' }
    * def articleNo = data.articles.digital.articleNumber
    * def orderNo = 'BOLTEST-' + uuid()
    * def lineId = 'LINE-' + uuid()
    * def licensedArticles =
      """
      function(res) {
        return karate.jsonPath(res, "$.schools[?(@.id=='" + data.school.id + "')].assignedLicenses[*].articleNumber");
      }
      """

  Scenario: A delivered license can be assigned to a user, listed, and unassigned

    # 1. Place an order. placeOrder also waits for the final result if the provider processes it asynchronously
    * def placed = placeOrder(newOrder(data, orderNo, [{ id: lineId, article: articleNo, quantity: 1 }]))
    Then match placed.httpStatus == 200
    And match placed.reply.clientOrderNumber == orderNo
    And match placed.reply.orderLines == '#[1]'
    And match placed.reply.orderLines[0] contains { clientOrderLineId: '#(lineId)', articleNumber: '#(articleNo)', status: 'delivered' }

    # The licenseKeys are optional. Providers that do not manage keys omit them
    * def licenseKey = karate.get('placed.reply.orderLines[0].licenseKeys[0]')

    # 2. Assign the license to a user, referring to the order line and key from step 1
    Given path 'v1', 'assignments', 'create'
    And request
      """
      {
        clientId: '#(data.clientId)',
        serviceProviderId: '#(data.serviceProviderId)',
        school: { idSource: '#(data.school.idSource)', id: '#(data.school.id)' },
        assignments: [{
          clientAssignmentId: '1',
          freeTrial: false,
          articleNumber: '#(articleNo)',
          clientOrderLineId: '#(lineId)',
          licenseKey: '##(licenseKey)',
          user: '#(data.user)'
        }]
      }
      """
    When method post
    Then status 200
    And match response.assignments == '#[1]'
    And match response.assignments[0] contains { clientAssignmentId: '1', status: 'assigned', articleUrl: '#string' }

    # 3. The user now has the article
    Given path 'v1', 'users', 'licenses'
    And request { clientId: '#(data.clientId)', serviceProviderId: '#(data.serviceProviderId)', user: '#(data.user)' }
    When method post
    Then status 200
    * def articles = licensedArticles(response)
    And match articles contains articleNo
    And match response.schools[*].assignedLicenses[*].articleUrl contains '#string'

    # 4. Unassign. The license must become assignable again
    Given path 'v1', 'assignments', 'delete'
    And request
      """
      {
        clientId: '#(data.clientId)',
        serviceProviderId: '#(data.serviceProviderId)',
        school: { idSource: '#(data.school.idSource)', id: '#(data.school.id)' },
        assignments: [{
          clientAssignmentId: '1',
          articleNumber: '#(articleNo)',
          clientOrderLineId: '#(lineId)',
          licenseKey: '##(licenseKey)',
          user: '#(data.user)'
        }]
      }
      """
    When method post
    Then status 200
    And match response.assignments[0] contains { clientAssignmentId: '1', status: 'unassigned' }

    # 5. The user no longer has the article
    Given path 'v1', 'users', 'licenses'
    And request { clientId: '#(data.clientId)', serviceProviderId: '#(data.serviceProviderId)', user: '#(data.user)' }
    When method post
    Then status 200
    * def articles = licensedArticles(response)
    And match articles !contains articleNo

    # 6. Because it was unassigned the same license can be assigned again
    Given path 'v1', 'assignments', 'create'
    And request
      """
      {
        clientId: '#(data.clientId)',
        serviceProviderId: '#(data.serviceProviderId)',
        school: { idSource: '#(data.school.idSource)', id: '#(data.school.id)' },
        assignments: [{
          clientAssignmentId: '2',
          freeTrial: false,
          articleNumber: '#(articleNo)',
          clientOrderLineId: '#(lineId)',
          licenseKey: '##(licenseKey)',
          user: '#(data.user)'
        }]
      }
      """
    When method post
    Then status 200
    And match response.assignments[0] contains { clientAssignmentId: '2', status: 'assigned' }

    # Clean up so that repeated runs leave the test school unchanged
    Given path 'v1', 'assignments', 'delete'
    And request
      """
      {
        clientId: '#(data.clientId)',
        serviceProviderId: '#(data.serviceProviderId)',
        school: { idSource: '#(data.school.idSource)', id: '#(data.school.id)' },
        assignments: [{
          clientAssignmentId: '3',
          articleNumber: '#(articleNo)',
          clientOrderLineId: '#(lineId)',
          licenseKey: '##(licenseKey)',
          user: '#(data.user)'
        }]
      }
      """
    When method post
    Then status 200
    And match response.assignments[0].status == 'unassigned'
