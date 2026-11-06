@ignore
Feature: Reference BOL service provider (mock)

  A minimal in-memory provider, used only to verify the test suite itself.
  Scenarios are tried in order and the first matching one answers.

  Background:
    * def data = read('classpath:testdata.json')
    * def orders = {}
    * def lines = {}
    * def assignments = {}
    * def keyOf = function(school, user, lineId){ return school + '|' + user + '|' + lineId }
    * def problemHeaders = { 'Content-Type': 'application/problem+json' }
    * def Async = Java.type('bol.Async')
    # With -Dbol.mock.async=true the provider answers "beingProcessed" and delivers through the responseUrl
    * def asyncMode = java.lang.System.getProperty('bol.mock.async') == 'true'
    * def placeOrder =
      """
      function(req) {
        orders[req.clientOrderNumber] = true;
        var digital = data.articles.digital.articleNumber;
        var delivered = [];
        var out = req.orderLines.map(function(l) {
          var r = { clientOrderLineId: l.clientOrderLineId, articleNumber: l.articleNumber, quantity: l.quantity };
          if (l.articleNumber == digital) {
            lines[l.clientOrderLineId] = l.articleNumber;
            var keys = ['KEY-' + l.clientOrderLineId];
            if (asyncMode) {
              r.status = 'beingProcessed';
              delivered.push({ clientOrderLineId: l.clientOrderLineId, articleNumber: l.articleNumber, quantity: l.quantity, status: 'delivered', licenseKeys: keys });
            } else {
              r.status = 'delivered';
              r.licenseKeys = keys;
            }
          } else {
            r.status = 'failed';
            r.errorMessage = 'Unknown article';
          }
          return r;
        });
        if (delivered.length > 0) {
          var later = { clientId: req.clientId, serviceProviderId: req.serviceProviderId, clientOrderNumber: req.clientOrderNumber, orderLines: delivered };
          Async.postLater(req.responseUrl, karate.toString(later), 1000);
        }
        return { clientId: req.clientId, serviceProviderId: req.serviceProviderId, clientOrderNumber: req.clientOrderNumber, orderLines: out };
      }
      """
    * def assign =
      """
      function(req) {
        var out = req.assignments.map(function(a) {
          var ok = lines[a.clientOrderLineId] != null;
          if (ok) {
            assignments[keyOf(req.school.id, a.user.id, a.clientOrderLineId)] =
              { school: req.school, user: a.user, articleNumber: a.articleNumber, licenseKey: 'KEY-' + a.clientOrderLineId };
          }
          return ok
            ? { clientAssignmentId: a.clientAssignmentId, articleUrl: 'https://provider.example.com/article/' + a.articleNumber, status: 'assigned' }
            : { clientAssignmentId: a.clientAssignmentId, articleUrl: 'https://provider.example.com/', status: 'failed', errorMessage: 'Unknown order line' };
        });
        return { clientId: req.clientId, serviceProviderId: req.serviceProviderId, assignments: out };
      }
      """
    * def unassign =
      """
      function(req) {
        var out = req.assignments.map(function(a) {
          var key = keyOf(req.school.id, a.user.id, a.clientOrderLineId);
          var found = assignments[key] != null;
          delete assignments[key];
          return found
            ? { clientAssignmentId: a.clientAssignmentId, status: 'unassigned' }
            : { clientAssignmentId: a.clientAssignmentId, status: 'failed', errorMessage: 'No such assignment' };
        });
        return { clientId: req.clientId, serviceProviderId: req.serviceProviderId, assignments: out };
      }
      """
    * def licensesOf =
      """
      function(req) {
        var bySchool = {};
        Object.keys(assignments).forEach(function(k) {
          var a = assignments[k];
          if (a.user.id != req.user.id) return;
          var s = bySchool[a.school.id] || (bySchool[a.school.id] = { idSource: a.school.idSource, id: a.school.id, assignedLicenses: [] });
          s.assignedLicenses.push({ articleNumber: a.articleNumber, licenseKey: a.licenseKey, articleName: 'Article ' + a.articleNumber, articleUrl: 'https://provider.example.com/article/' + a.articleNumber });
        });
        return { clientId: req.clientId, serviceProviderId: req.serviceProviderId, schools: Object.keys(bySchool).map(function(k){ return bySchool[k]; }) };
      }
      """

  Scenario: pathMatches('/v1/orders/create') && methodIs('post') && (!request.orderLines || request.orderLines.length == 0)
    * def responseStatus = 400
    * def responseHeaders = problemHeaders
    * def response = { type: 'about:blank', title: 'Bad Request', status: 400, errors: { orderLines: 'Order lines must contain at least one item' } }

  Scenario: pathMatches('/v1/orders/create') && methodIs('post') && orders[request.clientOrderNumber]
    * def responseStatus = 409
    * def responseHeaders = problemHeaders
    * def response = { type: 'about:blank', title: 'Conflict', status: 409, detail: 'Conflict: clientOrderNumber must have a unique value.' }

  Scenario: pathMatches('/v1/orders/create') && methodIs('post')
    * def response = placeOrder(request)

  Scenario: pathMatches('/v1/assignments/create') && methodIs('post')
    * def response = assign(request)

  Scenario: pathMatches('/v1/assignments/delete') && methodIs('post')
    * def response = unassign(request)

  Scenario: pathMatches('/v1/users/licenses') && methodIs('post')
    * def response = licensesOf(request)

  Scenario:
    * def responseStatus = 404
    * def responseHeaders = problemHeaders
    * def response = { title: 'Not Found', status: 404 }
