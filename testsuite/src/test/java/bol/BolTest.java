package bol;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import com.intuit.karate.core.MockServer;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class BolTest {

    private static MockServer mock;

    // With -Dbol.mock=true the suite runs against the bundled reference provider
    // instead of a real service provider. Used to verify the suite itself.
    @BeforeAll
    static void startMock() {
        if ("true".equals(System.getProperty("bol.mock"))) {
            mock = MockServer.feature("classpath:mock/provider-mock.feature").http(0).build();
            System.setProperty("bol.baseUrl", "http://localhost:" + mock.getPort());
            if (System.getProperty("bol.testdata") == null) {
                System.setProperty("bol.testdata", "classpath:mock/testdata.json");
            }
        }
    }

    @AfterAll
    static void stopMock() {
        if (mock != null) {
            mock.stop();
        }
    }

    @Test
    void conformance() {
        Results results = Runner.path("classpath:bol").parallel(1);
        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
