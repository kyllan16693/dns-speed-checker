//
//  Persistence.swift
//  DNS-speed-checker
//
//  Saves and restores the user's DNS providers, website lists, and enabled
//  toggles across launches via UserDefaults. Only durable fields are stored;
//  transient test results (speed/state) are reset on load.
//

import Foundation

enum Persistence {
  // Bump the providers key version when the bundled default list changes
  // meaningfully, so users pick up refreshed/added resolvers.
  // Same for the lists key: v2 introduces the small "Quick Test" default set.
  private static let providersKey = "dns_providers_v2"
  private static let listsKey = "website_lists_v2"

  private struct StoredProvider: Codable {
    var name: String
    var ipAddress: String
    var isEnabled: Bool
  }

  private struct StoredList: Codable {
    var name: String
    var websites: [String]
    var isEnabled: Bool
  }

  static func save(providers: [DNSProvider], lists: [WebsiteList]) {
    let storedProviders = providers.map {
      StoredProvider(name: $0.name, ipAddress: $0.ipAddress, isEnabled: $0.isEnabled)
    }
    let storedLists = lists.map {
      StoredList(name: $0.name, websites: $0.websites, isEnabled: $0.isEnabled)
    }
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(storedProviders) {
      UserDefaults.standard.set(data, forKey: providersKey)
    }
    if let data = try? encoder.encode(storedLists) {
      UserDefaults.standard.set(data, forKey: listsKey)
    }
  }

  static func loadProviders() -> [DNSProvider]? {
    guard let data = UserDefaults.standard.data(forKey: providersKey),
      let stored = try? JSONDecoder().decode([StoredProvider].self, from: data)
    else { return nil }
    return stored.map {
      DNSProvider(name: $0.name, ipAddress: $0.ipAddress, testState: .untested, isEnabled: $0.isEnabled)
    }
  }

  static func loadLists() -> [WebsiteList]? {
    guard let data = UserDefaults.standard.data(forKey: listsKey),
      let stored = try? JSONDecoder().decode([StoredList].self, from: data)
    else { return nil }
    return stored.map {
      WebsiteList(name: $0.name, websites: $0.websites, isEnabled: $0.isEnabled)
    }
  }
}
