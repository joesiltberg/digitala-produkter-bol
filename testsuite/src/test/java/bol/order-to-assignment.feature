Feature: Order and assign a license

  The core BOL flow, using only mandatory endpoints. Values from the order response
  (clientOrderLineId, licenseKeys) are used in the assignment request.

  Background:
    * url baseUrl
    * def newOrder = read('classpath:bol/common/new-order.js')
    * def placeOrder = function(order){ return karate.call('classpath:bol/common/place-order.feature', { order: order }) }
    * def uuid = function(){ return java.util.UUID.randomUUID() + '' }
    * def articleNo = data.articles.digital.articleNumber
    * def orderNo = 'BOLTEST-' + uuid()
    * def lineId = 'LINE-' + uuid()

  Scenario: A delivered license can be assigned to a user

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
