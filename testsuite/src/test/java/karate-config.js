// Global configuration. All provider-specific settings come from system properties or
// environment variables so the feature files stay provider-independent.
function fn() {
  var System = java.lang.System;
  function setting(prop, env) {
    return System.getProperty(prop) || System.getenv(env);
  }

  var baseUrl = setting('bol.baseUrl', 'BOL_BASE_URL');
  if (!baseUrl) {
    karate.fail('BOL_BASE_URL is not set. See testsuite/readme.md.');
  }

  var dataFile = setting('bol.testdata', 'BOL_TESTDATA');
  var data;
  if (!dataFile) {
    data = karate.read('classpath:testdata.json');
  } else if (dataFile.indexOf('classpath:') == 0) {
    data = karate.read(dataFile);
  } else {
    data = karate.read('file:' + dataFile);
  }
  data.capabilities = data.capabilities || {};

  // Optional parts of the standard. Features call this in Background and are skipped
  // (reported as passed) if the provider has not declared the capability.
  function requireCapability(name) {
    if (!data.capabilities[name]) {
      karate.logger.warn('SKIPPED: capability "' + name + '" is not enabled in the test data');
      karate.abort();
    }
  }

  // Receiver for asynchronous replies. The provider must be able to reach it.
  var callback = {
    port: parseInt(setting('bol.callbackPort', 'BOL_CALLBACK_PORT') || '0'),
    baseUrl: setting('bol.callbackBaseUrl', 'BOL_CALLBACK_BASE_URL'),
    timeoutSeconds: parseInt(setting('bol.callbackTimeout', 'BOL_CALLBACK_TIMEOUT') || '30')
  };

  var headerName = setting('bol.authHeaderName', 'BOL_AUTH_HEADER_NAME');
  var headerValue = setting('bol.authHeaderValue', 'BOL_AUTH_HEADER_VALUE');
  if (headerName && headerValue) {
    var headers = {};
    headers[headerName] = headerValue;
    karate.configure('headers', headers);
  }

  // Mutual TLS client certificate, e.g. a PKCS12 file
  var keyStore = setting('bol.keystore', 'BOL_KEYSTORE');
  if (keyStore) {
    karate.configure('ssl', {
      keyStore: keyStore,
      keyStorePassword: setting('bol.keystorePassword', 'BOL_KEYSTORE_PASSWORD') || '',
      keyStoreType: setting('bol.keystoreType', 'BOL_KEYSTORE_TYPE') || 'pkcs12'
    });
  } else if (setting('bol.insecureTls', 'BOL_INSECURE_TLS') == 'true') {
    karate.configure('ssl', true);
  }

  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 30000);

  return { baseUrl: baseUrl, data: data, requireCapability: requireCapability, callbackCfg: callback };
}
