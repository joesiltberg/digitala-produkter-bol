@ignore
Feature: Callback receiver

  Started by features that test asynchronous replies. Every request is put on the queue
  passed in as "queue", and the test waits for it there. The queue is shared with the
  test through the arg of karate.start().

  Scenario:
    * queue.offer(karate.toString({ method: requestMethod, path: requestPath, body: request }))
    * def response = {}
