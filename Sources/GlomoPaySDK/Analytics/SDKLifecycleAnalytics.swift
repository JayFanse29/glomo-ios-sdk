import Foundation

enum SDKCloseTrigger: String {
    case userDismiss = "user_dismiss"
    case merchant
    case page
    case completed
    case error

    init(_ source: TerminationSource) {
        switch source {
        case .userDismiss: self = .userDismiss
        case .programmatic: self = .merchant
        case .connectionError: self = .error
        }
    }

    init(_ result: GlomoPayResult) {
        switch result {
        case .success, .failure, .userJourney, .cancelled: self = .completed
        case .pageClosed: self = .page
        }
    }
}

enum SDKFailureCode: String {
    case openTimeout = "open_timeout"
    case connectionError = "connection_error"
    case webViewError = "webview_error"
    case httpError = "http_error"
    case validationFailed = "validation_failed"
    case orderTypeDetectionFailed = "order_type_detection_failed"
    case complianceBlocked = "compliance_blocked"
    case dependenciesFailed = "dependencies_failed"
    case startFailed = "start_failed"

    init(_ type: ConnectionErrorType) {
        switch type {
        case .noInternet, .dnsFailure, .timeout, .sslError: self = .connectionError
        case .httpClientError, .httpServerError: self = .httpError
        case .webResourceError, .unknown: self = .webViewError
        }
    }
}

extension AnalyticsTracking {
    func trackSDKLoaded() {
        self.track(AnalyticsEventName.sdkLoaded, properties: ["integration": GlomoPaySDKBuild.integration])
    }

    func trackSDKClosed(_ trigger: SDKCloseTrigger) {
        self.track(AnalyticsEventName.sdkClosed, properties: [
            "integration": GlomoPaySDKBuild.integration,
            "trigger": trigger.rawValue,
        ])
    }

    func trackSDKFailed(_ code: SDKFailureCode) {
        self.track(AnalyticsEventName.sdkFailed, properties: [
            "integration": GlomoPaySDKBuild.integration,
            "error_code": code.rawValue,
        ])
    }
}
