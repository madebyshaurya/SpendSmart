import Foundation

struct PopularSubscriptionItem: Identifiable {
    let id = UUID()
    let serviceName: String
    let domain: String
    let defaultAmount: Double?
    let category: ServiceCategory

    // Logo URL is now fetched dynamically via BrandfetchService
    // This property is kept for backward compatibility but returns empty string
    // Use BrandfetchService.shared.fetchLogo(for:) instead
    var logoURL: String { "" }
}

enum ServiceCategory: String, CaseIterable {
    case streaming = "Streaming"
    case productivity = "Productivity"
    case music = "Music"
    case cloud = "Cloud"
    case other = "Other"
}

enum PopularSubscriptions {
    static let items: [PopularSubscriptionItem] = [
        // Streaming
        .init(serviceName: "Netflix", domain: "netflix.com", defaultAmount: 15.49, category: .streaming),
        .init(serviceName: "Amazon Prime Video", domain: "primevideo.com", defaultAmount: 8.99, category: .streaming),
        .init(serviceName: "Disney+", domain: "disneyplus.com", defaultAmount: 7.99, category: .streaming),
        .init(serviceName: "Max (HBO)", domain: "max.com", defaultAmount: 9.99, category: .streaming),
        .init(serviceName: "Hulu", domain: "hulu.com", defaultAmount: 7.99, category: .streaming),
        .init(serviceName: "Paramount+", domain: "paramountplus.com", defaultAmount: 5.99, category: .streaming),
        .init(serviceName: "Peacock", domain: "peacocktv.com", defaultAmount: 5.99, category: .streaming),
        
        // Music
        .init(serviceName: "Spotify", domain: "spotify.com", defaultAmount: 10.99, category: .music),
        .init(serviceName: "Apple Music", domain: "apple.com", defaultAmount: 10.99, category: .music),
        .init(serviceName: "Tidal", domain: "tidal.com", defaultAmount: 9.99, category: .music),
        
        // Cloud
        .init(serviceName: "Apple iCloud+", domain: "apple.com", defaultAmount: 2.99, category: .cloud),
        .init(serviceName: "Dropbox", domain: "dropbox.com", defaultAmount: 11.99, category: .cloud),
        .init(serviceName: "Google One", domain: "google.com", defaultAmount: 1.99, category: .cloud),
        
        // Productivity
        .init(serviceName: "Microsoft 365", domain: "microsoft.com", defaultAmount: 6.99, category: .productivity),
        .init(serviceName: "Notion", domain: "notion.so", defaultAmount: 8.00, category: .productivity),
        .init(serviceName: "Adobe Creative Cloud", domain: "adobe.com", defaultAmount: 20.99, category: .productivity),
        .init(serviceName: "Canva", domain: "canva.com", defaultAmount: 12.99, category: .productivity),
        .init(serviceName: "GitHub", domain: "github.com", defaultAmount: 4.00, category: .productivity),
        .init(serviceName: "Slack", domain: "slack.com", defaultAmount: nil, category: .productivity),
        .init(serviceName: "Zoom", domain: "zoom.us", defaultAmount: nil, category: .productivity),
        .init(serviceName: "Evernote", domain: "evernote.com", defaultAmount: 7.99, category: .productivity),
        .init(serviceName: "Todoist", domain: "todoist.com", defaultAmount: 4.00, category: .productivity),
        .init(serviceName: "Monday.com", domain: "monday.com", defaultAmount: nil, category: .productivity),
        .init(serviceName: "Asana", domain: "asana.com", defaultAmount: nil, category: .productivity),
        .init(serviceName: "Figma", domain: "figma.com", defaultAmount: nil, category: .productivity),
        
        // Other
        .init(serviceName: "YouTube Premium", domain: "youtube.com", defaultAmount: 13.99, category: .other),
        .init(serviceName: "1Password", domain: "1password.com", defaultAmount: 2.99, category: .other),
        .init(serviceName: "LastPass", domain: "lastpass.com", defaultAmount: 3.00, category: .other),
        .init(serviceName: "NordVPN", domain: "nordvpn.com", defaultAmount: 12.99, category: .other),
        .init(serviceName: "ExpressVPN", domain: "expressvpn.com", defaultAmount: 12.95, category: .other),
        .init(serviceName: "Audible", domain: "audible.com", defaultAmount: 7.95, category: .other),
        .init(serviceName: "Kindle Unlimited", domain: "amazon.com", defaultAmount: 9.99, category: .other),
        .init(serviceName: "Headspace", domain: "headspace.com", defaultAmount: 12.99, category: .other),
        .init(serviceName: "Calm", domain: "calm.com", defaultAmount: 12.99, category: .other),
        .init(serviceName: "Coursera", domain: "coursera.org", defaultAmount: nil, category: .other),
        .init(serviceName: "Duolingo", domain: "duolingo.com", defaultAmount: 6.99, category: .other),
        .init(serviceName: "Canary Mail", domain: "canarymail.io", defaultAmount: nil, category: .other),
        .init(serviceName: "Setapp", domain: "setapp.com", defaultAmount: 9.99, category: .other)
    ]

    // Logos are now fetched dynamically via BrandfetchService
    // This method is kept for backward compatibility but returns nil
    // Use BrandfetchService.shared.fetchLogo(for:) instead
    static func logoURL(for serviceName: String) -> String? {
        return nil
    }
}


