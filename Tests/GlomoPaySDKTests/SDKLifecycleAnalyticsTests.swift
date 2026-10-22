import XCTest
@testable import GlomoPaySDK

final class SDKLifecycleAnalyticsTests: XCTestCase {
    func testTerminationSourcesMapOntoCloseTriggers() {
        XCTAssertEqual(SDKCloseTrigger(TerminationSource.userDismiss), .userDismiss)
        XCTAssertEqual(SDKCloseTrigger(TerminationSource.programmatic), .merchant)
        XCTAssertEqual(SDKCloseTrigger(TerminationSource.connectionError), .error)
        XCTAssertEqual(
            [SDKCloseTrigger.userDismiss, .merchant, .page, .completed, .error].map(\.rawValue),
            ["user_dismiss", "merchant", "page", "completed", "error"]
        )
    }

    func testTerminalResultsCloseAsCompletedAndAPageCloseAsPage() {
        let payload = GlomoPayPayload(json: ["orderId": "order_123456"])
        let completed: [GlomoPayResult] = [
            .success(payload),
            .failure(message: "Payment failed", code: nil),
            .userJourney(GlomoPayUserJourneyPayload(journeyType: .bankTransferSubmitted, json: [:])),
            .cancelled,
        ]

        XCTAssertEqual(completed.map(SDKCloseTrigger.init), Array(repeating: .completed, count: 4))
        XCTAssertEqual(SDKCloseTrigger(GlomoPayResult.pageClosed), .page)
    }

    func testConnectionErrorTypesMapOntoFailureCodes() {
        let expected: [(ConnectionErrorType, String)] = [
            (.noInternet, "connection_error"),
            (.dnsFailure, "connection_error"),
            (.timeout, "connection_error"),
            (.sslError, "connection_error"),
            (.httpClientError, "http_error"),
            (.httpServerError, "http_error"),
            (.webResourceError, "webview_error"),
            (.unknown, "webview_error"),
        ]

        for (type, code) in expected {
            XCTAssertEqual(SDKFailureCode(type).rawValue, code, type.rawValue)
        }
    }

    func testPageCloseIsReportedAsPageAndStillTellsTheHostUserDismiss() {
        let listener = TerminationRecordingListener()
        var results: [GlomoPayResult] = []
        let router = GlomoPayEventRouter(
            listener: listener,
            devMode: false,
            onComplete: { results.append($0) },
            analytics: NoOpAnalyticsTracker(),
            errorReporter: NoOpSDKErrorReporter()
        )

        router.handle(envelope: ["type": "message", "data": ["type": "checkout.closed"]])

        XCTAssertEqual(results.map(SDKCloseTrigger.init), [.page])
        XCTAssertEqual(listener.terminations, [.userDismiss])
    }

    func testOnlyAMainWebViewDependencyFailureReachesTheSDKFailureHook() {
        let analytics = PropertyRecordingAnalytics()
        var mainFailures = 0
        let router = GlomoPayEventRouter(
            listener: nil,
            devMode: false,
            onComplete: { _ in },
            onMainDependenciesFailed: { mainFailures += 1 },
            analytics: analytics,
            errorReporter: NoOpSDKErrorReporter()
        )
        let envelope: [String: Any] = ["type": "dependencies.failed_to_load", "message": "LRS data missing"]

        router.handle(envelope: envelope, source: .flow)
        XCTAssertEqual(mainFailures, 0)
        router.handle(envelope: envelope)
        XCTAssertEqual(mainFailures, 1)
        router.handle(body: #"{"type":"dependencies.failed_to_load"}"#, source: .flow)

        XCTAssertEqual(mainFailures, 1)
        XCTAssertEqual(analytics.events.filter { $0.name == AnalyticsEventName.checkoutDependenciesFailed }.count, 3)
        XCTAssertTrue(analytics.events.filter { $0.name == AnalyticsEventName.sdkFailed }.isEmpty)
    }
}

private final class TerminationRecordingListener: GlomoPayListener {
    var terminations: [TerminationSource] = []

    func onPaymentSuccess(_ payload: GlomoPayPayload) {}
    func onPaymentFailure(_ payload: GlomoPayPayload) {}
    func onSdkError(_ errors: [SdkError]) {}
    func onUserJourneyCompleted(_ payload: GlomoPayUserJourneyPayload) {}
    func onConnectionError(_ error: ConnectionError) {}
    func onPaymentTerminate(_ source: TerminationSource) { terminations.append(source) }
}

private final class PropertyRecordingAnalytics: AnalyticsTracking {
    var events: [(name: String, properties: [String: Any?])] = []
    func track(_ event: String, properties: [String: Any?]) { events.append((event, properties)) }
    func updateFlowType(_ flowType: String) {}
    func updateCheckoutURL(_ url: URL) {}
}
