package bol;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

/** Used by the reference provider to deliver asynchronous replies. Not used by the tests themselves. */
public final class Async {

    private static final HttpClient CLIENT = HttpClient.newHttpClient();

    private Async() {
    }

    public static void postLater(String url, String json, long delayMillis) {
        Thread t = new Thread(() -> {
            try {
                Thread.sleep(delayMillis);
                HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                        .header("Content-Type", "application/json")
                        .POST(HttpRequest.BodyPublishers.ofString(json))
                        .build();
                CLIENT.send(request, HttpResponse.BodyHandlers.discarding());
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
        t.setDaemon(true);
        t.start();
    }
}
