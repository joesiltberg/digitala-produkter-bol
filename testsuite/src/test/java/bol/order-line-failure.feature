Feature: A processed order reports failures per order line

  An order that is processed gets HTTP 200 even if a line fails. The outcome is
  reported in orderLines[].status, and failed lines carry an errorMessage.

  Background:
    * url baseUrl
    * def newOrder = read('classpath:bol/common/new-order.js')
    * def placeOrder = function(order){ return karate.call('classpath:bol/common/place-order.feature', { order: order }) }
    * def uuid = function(){ return java.util.UUID.randomUUID() + '' }

  Scenario: One failing line does not fail the other line, and ids are echoed

    * def orderNo = 'BOLTEST-' + uuid()
    * def goodLine = 'LINE-' + uuid()
    * def badLine = 'LINE-' + uuid()
    * def good = data.articles.digital.articleNumber
    * def bad = data.articles.unknown.articleNumber

    * def placed = placeOrder(newOrder(data, orderNo, [{ id: goodLine, article: good }, { id: badLine, article: bad }]))
    Then match placed.httpStatus == 200
    And match placed.reply.clientOrderNumber == orderNo
    And match placed.reply.orderLines == '#[2]'

    # Lines are matched on clientOrderLineId, the response order is not significant
    * def byId = function(id){ return karate.filter(placed.reply.orderLines, function(l){ return l.clientOrderLineId == id })[0] }
    And match byId(goodLine) contains { articleNumber: '#(good)', status: 'delivered' }
    And match byId(badLine) contains { articleNumber: '#(bad)', status: 'failed', errorMessage: '#string' }
