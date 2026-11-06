# BOL conformance test suite (draft)

Executable examples of how a BOL 1 service provider is expected to behave. They double as
documentation of the standard and as a test suite for implementers. The tests are written in
[Karate](https://github.com/karatelabs/karate) (MIT licensed), whose `.feature` files are
readable without programming experience.

This is a small starting point, not full coverage. It contains four features:

| Feature | Illustrates |
|---|---|
| [order-to-assignment.feature](src/test/java/bol/order-to-assignment.feature) | The core flow, using only mandatory endpoints: order, then assign. `clientOrderLineId` and `licenseKeys` from the order response are reused in the assignment request. Providers that do not manage license keys are supported (`licenseKey` is then omitted). Works whether the provider answers the order directly or asynchronously. |
| [assignment-lifecycle.feature](src/test/java/bol/assignment-lifecycle.feature) | **Optional** (capabilities `assignmentDelete` and `userLicenses`). Order, assign, list the user's licenses, unassign, list again, reassign the same license, clean up. |
| [order-errors.feature](src/test/java/bol/order-errors.feature) | Unprocessable requests give a non-2xx status and `application/problem+json`: 400 for an order without lines, 409 for a reused `clientOrderNumber` (after a first, successful order). |
| [order-line-failure.feature](src/test/java/bol/order-line-failure.feature) | A processed order gets HTTP 200 even if a line fails; the outcome is per line (`status`, `errorMessage`), and lines are matched on `clientOrderLineId`. |

## Running the tests

Requirements: either Docker, or Java 17+ and Maven.

### Against a service provider

Set the environment variables described in the [execution contract](#execution-contract), then:

```bash
docker run --rm -v "$PWD:/work" -v bol-m2:/root/.m2 -w /work \
  -e BOL_BASE_URL=https://bol.provider.example.com \
  -e BOL_AUTH_HEADER_NAME=Authorization -e BOL_AUTH_HEADER_VALUE="Bearer <token>" \
  maven:3.9-eclipse-temurin-17 mvn -B test
```

or, with a local Java and Maven:

```bash
export BOL_BASE_URL=https://bol.provider.example.com
mvn test
```

Without `BOL_TESTDATA` the defaults in [testdata.json](src/test/java/testdata.json) are used, which
declares no optional capabilities. To use your own test data, put a copy of that file in this
directory and point to it. With Docker the path is the one inside the container (`/work/...`):

```bash
docker run --rm -v "$PWD:/work" -v bol-m2:/root/.m2 -w /work \
  -e BOL_BASE_URL=https://bol.provider.example.com \
  -e BOL_TESTDATA=/work/my-testdata.json \
  maven:3.9-eclipse-temurin-17 mvn -B test
```

With a local Java and Maven, use `export BOL_TESTDATA=./my-testdata.json` instead.

Run these from this directory. On Windows PowerShell use `"${PWD}:/work"` for the volume and
quote `-D` arguments, for example `"-Dbol.mock=true"`.

Reports are written to `target/karate-reports/karate-summary.html`.
A single feature can be run with `mvn test -Dkarate.options="classpath:bol/order-errors.feature"`.

### Against the bundled reference provider

To check the suite itself, run it against a minimal in-memory provider
([provider-mock.feature](src/test/java/mock/provider-mock.feature)). No configuration is needed:

```bash
mvn test -Dbol.mock=true
```

Add `-Dbol.mock.async=true` to make the reference provider answer orders asynchronously instead
(`beingProcessed`, then a callback after one second). The same tests pass in both modes.

The mock also serves as a compact, executable description of the minimum behaviour the tests expect.

## Execution contract

The contract describes what the service provider must set up, and what the suite promises to do.

### Configuration

Set by environment variables (or the equivalent `-D` system property in parentheses):

| Variable | Required | Description |
|---|---|---|
| `BOL_BASE_URL` (`bol.baseUrl`) | yes | Base URL of the provider's BOL endpoints, without trailing slash. Endpoints are `{BOL_BASE_URL}/v1/...`. Must be a test environment. |
| `BOL_AUTH_HEADER_NAME`, `BOL_AUTH_HEADER_VALUE` | no | Header sent on every request, for token or API key authentication. |
| `BOL_KEYSTORE`, `BOL_KEYSTORE_PASSWORD`, `BOL_KEYSTORE_TYPE` | no | Client certificate for mutual TLS. Type defaults to `pkcs12`. |
| `BOL_INSECURE_TLS` | no | `true` makes the tests trust any server certificate. Only for local test servers. |
| `BOL_TESTDATA` | no | Path to a copy of [testdata.json](src/test/java/testdata.json) with provider-specific values and capabilities, see below. |
| `BOL_CALLBACK_PORT` (`bol.callbackPort`) | if the provider answers asynchronously | Port the test runner listens on for asynchronous replies. Defaults to a random free port. |
| `BOL_CALLBACK_BASE_URL` (`bol.callbackBaseUrl`) | if the provider answers asynchronously | The address at which the **provider** reaches the test runner, e.g. `https://abc.tunnel.example.com`, forwarding to the callback port. Defaults to `http://localhost:<port>`, which only works if the provider runs on the same machine. If set, also set `BOL_CALLBACK_PORT`. |
| `BOL_CALLBACK_TIMEOUT` (`bol.callbackTimeout`) | no | Seconds to wait for an asynchronous order reply. Default 30. |

### Capabilities

Parts of the standard are optional. A provider declares which it supports in the `capabilities`
section of its test data file. All capabilities are off in the default
[testdata.json](src/test/java/testdata.json), so a provider opts in explicitly.

| Capability | Meaning |
|---|---|
| `assignmentDelete` | The provider implements `/v1/assignments/delete`, which the standard marks as not mandatory. |
| `userLicenses` | The provider implements `/v1/users/licenses`, which the standard marks as not mandatory. |

Whether a provider answers orders synchronously or asynchronously is deliberately **not** a
capability: it is the provider's choice, and every test must work with both (see below).


Features for an optional capability start with `* requireCapability('<name>')` in `Background`.
If the capability is off, the feature is skipped. Karate reports a skipped scenario as *passed*,
so the HTML report shows no failure; the log contains `SKIPPED: capability ...`.

### Test data the provider must set up

The provider configures its **test environment** (never production) with the data below, or
supplies a `BOL_TESTDATA` file with its own values (a copy of [testdata.json](src/test/java/testdata.json),
starting with `classpath:` or a file path). The defaults are in
[testdata.json](src/test/java/testdata.json).

| Item | Default value | Requirement |
|---|---|---|
| Client id | `https://bol-testclient.example.com` | Known client; the credentials above authenticate as this client. |
| Service provider id | `https://bol-testprovider.example.com` | The provider's id. |
| School | `idSource: skolverket`, `id: 00000001` | The provider accepts this school. If the provider maps schools internally, it still has to return the original id (README, "Managing school unit groups"). |
| User | `idSource: eppn`, `id: bol-testuser-1@bol-testschool.example.com` | The provider accepts assignments to this user. |
| Article `digital` | `BOLTEST-DIGITAL-1` | A digital article that can be ordered any number of times and assigned to users. The provider decides whether it has license keys. |
| Article `unknown` | `BOLTEST-DOES-NOT-EXIST` | Must **not** exist at the provider; an order line with it is expected to fail (`status: failed`). |

Not covered yet (and therefore not required): backorders, asynchronous replies for other endpoints
than orders, hybrid articles and bundles, free trials, `/v1/school-units/...` endpoints, and
pricing/discount fields.

### Rules the suite follows

- **Isolation:** every run uses unique `clientOrderNumber` and `clientOrderLineId` values (`BOLTEST-<uuid>`), so runs can be repeated and do not collide with other data.
- **Clean up:** if the provider supports `assignmentDelete`, every assignment made by a test is deleted again, so the test user ends with no licenses. Without it, the core feature leaves one assignment per run on the test user. Orders cannot be removed through the API, so a run leaves orders behind; the provider may purge `BOLTEST-*` orders.
- **No ordering between features:** each feature (and scenario) is independent and can be run alone. Steps within a scenario depend on earlier steps.
- **No shared state, sequential execution:** the tests run one at a time, and the test client has the test school and user for itself.
- **Sync or async orders:** tests place orders through `placeOrder(...)` ([place-order.feature](src/test/java/bol/common/place-order.feature)). It always sends a `responseUrl` pointing at a temporary receiver. If the order reply contains lines that are `beingProcessed`, it waits for the provider's HTTP POST to the `responseUrl` (same JSON format as an order reply, only updated lines needed; the receiver answers 200) and merges it into the result. Tests then assert on the final result and cannot tell which mode was used. If no callback arrives within the timeout the run fails.
- **Requests are valid:** requests contain all required fields according to [BOLv1_openapi301.json](../BOLv1_openapi301.json) and nothing else, apart from the optional fields stated in the features.
- **Assertions are limited to what the standard states:** the tests check the fields and status values they need (with `contains`), and ignore additional properties in responses.

## Layout

```
testsuite/
  pom.xml                           Maven build (Karate 1.4.1, JUnit 5)
  src/test/java/
    karate-config.js                reads configuration, exposes baseUrl, data, requireCapability and callbackCfg to the features
    logback-test.xml                log levels, keeps the console output to the summary
    testdata.json                   default test data (all capabilities off)
    bol/BolTest.java                JUnit entry point, runs all features in bol/
    bol/*.feature                   the tests
    bol/common/new-order.js         shared helper that builds an order request
    bol/common/place-order.feature  places an order, hides sync/async, returns httpStatus, contentType and reply
    bol/common/callback-receiver.feature  receives asynchronous order replies
    mock/provider-mock.feature      reference provider, used to check the suite
    mock/testdata.json              test data for the reference provider (all capabilities on)
    bol/Async.java                  lets the reference provider post delayed replies (async mode)
```

## Writing tests

A test is a sequence of requests, where a value from one response is stored in a variable and
used in the next request:

```gherkin
* def placed = placeOrder(newOrder(data, orderNo, [{ id: lineId, article: articleNo }]))
Then match placed.httpStatus == 200
* def licenseKey = karate.get('placed.reply.orderLines[0].licenseKeys[0]')

Given path 'v1', 'assignments', 'create'
And request { ..., assignments: [{ clientOrderLineId: '#(lineId)', licenseKey: '##(licenseKey)', ... }] }
```

`'#(x)'` embeds a variable, and `'##(x)'` omits the field if it has no value. See the
[Karate documentation](https://github.com/karatelabs/karate) for the full syntax.
