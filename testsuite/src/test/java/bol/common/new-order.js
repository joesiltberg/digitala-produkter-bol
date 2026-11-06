// Builds a valid /v1/orders/create request body from the test data.
// orderLines is a list of { id, article, quantity }.
function(data, clientOrderNumber, orderLines) {
  return {
    clientId: data.clientId,
    serviceProviderId: data.serviceProviderId,
    clientOrderNumber: clientOrderNumber,
    buyer: {
      type: data.buyer.type,
      organizationNumber: data.buyer.organizationNumber,
      name: data.buyer.name,
      school: data.school
    },
    orderLines: orderLines.map(function(l) {
      return { clientOrderLineId: l.id, articleNumber: l.article, quantity: l.quantity || 1 };
    })
  };
}
