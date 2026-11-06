Feature: Rejected orders use application/problem+json

  Requests that cannot be processed get a non-2xx status and an RFC 9457
  application/problem+json body. Requests that are processed get 200 and report
  the outcome in the "status" fields.

  Background:
    * url baseUrl
    * def newOrder = read('classpath:bol/common/new-order.js')
    * def placeOrder = function(order){ return karate.call('classpath:bol/common/place-order.feature', { order: order }) }
    * def uuid = function(){ return java.util.UUID.randomUUID() + '' }
    * def articleNo = data.articles.digital.articleNumber

  Scenario: An order without order lines is rejected with 400

    * def placed = placeOrder(newOrder(data, 'BOLTEST-' + uuid(), []))
    Then match placed.httpStatus == 400
    And match placed.contentType contains 'application/problem+json'
    And match placed.reply contains { title: '#string', status: 400 }

  Scenario: Reusing a clientOrderNumber is rejected with 409

    * def orderNo = 'BOLTEST-' + uuid()

    # The first order is accepted
    * def first = placeOrder(newOrder(data, orderNo, [{ id: 'LINE-' + uuid(), article: articleNo, quantity: 1 }]))
    Then match first.httpStatus == 200
    And match first.reply.clientOrderNumber == orderNo

    # The same clientOrderNumber must have a unique value
    * def second = placeOrder(newOrder(data, orderNo, [{ id: 'LINE-' + uuid(), article: articleNo, quantity: 1 }]))
    Then match second.httpStatus == 409
    And match second.contentType contains 'application/problem+json'
    And match second.reply contains { title: '#string', status: 409 }
