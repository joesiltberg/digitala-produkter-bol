@ignore
Feature: Place an order and wait for the final result

  Hides whether the service provider answers synchronously or asynchronously, so that
  tests do not have to care. Use it through placeOrder(order), defined in a feature's Background as
  (without the quotes) "def placeOrder = function(order){ return karate.call('classpath:bol/common/place-order.feature', { order: order }) }".
  The order is sent with a responseUrl that points to a temporary receiver in the test runner.
  If the reply has lines with status "beingProcessed", the final results are awaited at the
  receiver, and the updated lines are merged into the reply (lines are matched on
  clientOrderLineId, as the asynchronous replies only contain updated lines). A provider
  that answers directly never calls the receiver.

  The result has:
    httpStatus   HTTP status of the order request. Not asserted here, the test decides what to expect
    contentType  Content-Type of the reply
    reply        The reply body. For a processed order the reply where all "beingProcessed" lines
                 have been replaced by their final result

  "backordered" lines are not waited for as the delivery can take days. They are returned as is.

  Scenario:
    * url baseUrl
    * def orderNo = order.clientOrderNumber
    * def queue = new java.util.concurrent.LinkedBlockingQueue()
    * def receiver = karate.start({ mock: 'classpath:bol/common/callback-receiver.feature', port: callbackCfg.port, arg: { queue: queue } })
    * def callbackUrl = (callbackCfg.baseUrl || 'http://localhost:' + receiver.port) + '/bol/orders'
    * set order.responseUrl = callbackUrl

    * def awaitFinalResult =
      """
      function(initial) {
        var TimeUnit = Java.type('java.util.concurrent.TimeUnit');
        var System = java.lang.System;
        function pending(r) {
          return r.orderLines && r.orderLines.some(function(l) { return l.status == 'beingProcessed'; });
        }
        try {
          var current = initial;
          var deadline = System.currentTimeMillis() + callbackCfg.timeoutSeconds * 1000;
          while (pending(current)) {
            var remaining = deadline - System.currentTimeMillis();
            var message = remaining > 0 ? queue.poll(remaining, TimeUnit.MILLISECONDS) : null;
            if (message == null) {
              throw new Error('Order ' + orderNo + ' is still being processed, but no reply was received at the responseUrl within ' + callbackCfg.timeoutSeconds + ' seconds');
            }
            var callback = karate.fromString(message);
            if (callback.method != 'POST' || callback.body.clientOrderNumber != orderNo) {
              throw new Error('Unexpected call to the responseUrl: ' + message);
            }
            var updates = callback.body.orderLines;
            current = {
              clientId: current.clientId,
              serviceProviderId: current.serviceProviderId,
              clientOrderNumber: current.clientOrderNumber,
              orderLines: current.orderLines.map(function(l) {
                var u = updates.filter(function(x) { return x.clientOrderLineId == l.clientOrderLineId; });
                return u.length > 0 ? u[0] : l;
              })
            };
          }
          return current;
        } finally {
          receiver.stop();
        }
      }
      """
    * def headerOf =
      """
      function(name) {
        var keys = karate.keysOf(responseHeaders);
        for (var i = 0; i < keys.length; i++) {
          if (keys[i].toLowerCase() == name) return responseHeaders[keys[i]][0];
        }
        return null;
      }
      """

    Given path 'v1', 'orders', 'create'
    And request order
    When method post
    * def httpStatus = responseStatus
    * def contentType = headerOf('content-type')
    * def reply = awaitFinalResult(response)
