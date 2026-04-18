import Foundation

// MARK: - Deep Link Manager

/// Handles parsing and creating deep link URLs for ForkBook.
/// URL Scheme: forkbook://
/// Supported paths:
///   - forkbook://join-circle?code=ABCDEF
struct DeepLinkManager {

    // MARK: - Deep Link Types

    enum DeepLink: Equatable {
        case joinCircle(code: String)
        case unknown
    }

    // MARK: - Parsing

    /// Parse an incoming URL into a DeepLink action.
    static func parse(url: URL) -> DeepLink {
        guard url.scheme == "forkbook" else { return .unknown }

        switch url.host {
        case "join-circle":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
               code.count == 6 {
                return .joinCircle(code: code.uppercased())
            }
            return .unknown
        default:
            return .unknown
        }
    }

    // MARK: - Link Generation

    /// Generate a shareable deep link URL for joining a circle.
    static func makeInviteLink(code: String) -> URL {
        var components = URLComponents()
        components.scheme = "forkbook"
        components.host = "join-circle"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url!
    }

    /// Generate a shareable text message with the deep link.
    static func makeInviteMessage(circleName: String, code: String) -> String {
        let link = makeInviteLink(code: code)
        return "Join my ForkBook table \"\(circleName)\"!\n\nTap to join: \(link.absoluteString)\n\nOr enter code: \(code)"
    }
}
