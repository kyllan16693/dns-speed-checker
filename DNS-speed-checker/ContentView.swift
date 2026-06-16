//
//  ContentView.swift
//  DNS-speed-checker
//
//  Created by Kyllan Wunder on 5/5/24.
//
import SwiftUI
import SystemConfiguration

// Function to get current DNS servers used by the system
func getCurrentDNSServers() -> [String] {
  var dnsServers = [String]()
  if let dnsConfig = SCDynamicStoreCopyValue(nil, "State:/Network/Global/DNS" as CFString)
    as? [String: Any],
    let servers = dnsConfig["ServerAddresses"] as? [String]
  {
    dnsServers = servers
  }
  return dnsServers
}

// DNSProvider structure
struct DNSProvider: Identifiable, Comparable {
  let id = UUID()
  var name: String
  var ipAddress: String
  var speed: TimeInterval?
  var fastest: TimeInterval?
  var slowest: TimeInterval?
  var testState: TestState
  var isEnabled: Bool = true
  // Detailed results captured during a test run (transient, not persisted).
  var coldStart: TimeInterval?
  var samples: [TimeInterval] = []
  var attempts: Int = 0
  // Cache-busting (uncached) measurements: random subdomains force a full
  // recursive lookup, so these reflect upstream resolution, not just RTT.
  var uncachedSpeed: TimeInterval?
  var uncachedSamples: [TimeInterval] = []
  var uncachedAttempts: Int = 0

  enum TestState {
    case untested, testing, tested
  }

  static func < (lhs: DNSProvider, rhs: DNSProvider) -> Bool {
    guard let lhsSpeed = lhs.speed, let rhsSpeed = rhs.speed else {
      return false
    }
    return lhsSpeed < rhsSpeed
  }
}

// WebsiteList structure
struct WebsiteList: Identifiable {
  let id = UUID()
  var name: String
  var websites: [String]
  var isEnabled: Bool
}

//Since swift does not allow text placeholders in forms
struct CustomTextField: View {
  @Binding var text: String
  var placeholder: String

  var body: some View {
    ZStack(alignment: .leading) {
      if text.isEmpty {
        Text(placeholder)
          .foregroundColor(.gray)
          .padding(.leading, 14)
      }
      TextField("", text: $text)
        .padding(.leading, -5)
        .textFieldStyle(RoundedBorderTextFieldStyle())
    }.padding(.top, 1).padding(.bottom, 1)
  }
}

// Function to validate IP address when user adds a new DNS provider
func isValidIPAddress(ipAddress: String) -> Bool {
  let ipAddressPattern =
    "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
  if let _ = ipAddress.range(of: ipAddressPattern, options: .regularExpression) {
    return true
  }
  return false
}

// Function to validate URL when user adds a new website
func isValidURL(url: String) -> Bool {
  let urlRegEx = "^(http|https)://[^\\s/$.?#].[^\\s]*$"
  if let _ = url.range(of: urlRegEx, options: .regularExpression) {
    return true
  }
  return false
}

// Main ContentView with DNS providers and website lists
struct ContentView: View {
  @State private var dnsProviders: [DNSProvider] =
    Persistence.loadProviders() ?? ContentView.defaultProviders
  @State private var websiteLists: [WebsiteList] =
    Persistence.loadLists() ?? ContentView.defaultWebsiteLists

  static let defaultProviders: [DNSProvider] = [
    DNSProvider(name: "Google", ipAddress: "8.8.8.8", testState: .untested),
    DNSProvider(name: "Google (secondary)", ipAddress: "8.8.4.4", testState: .untested),
    DNSProvider(name: "Cloudflare", ipAddress: "1.1.1.1", testState: .untested),
    DNSProvider(name: "Cloudflare (secondary)", ipAddress: "1.0.0.1", testState: .untested),
    DNSProvider(name: "Cloudflare Malware-Blocking", ipAddress: "1.1.1.2", testState: .untested),
    DNSProvider(name: "Cloudflare Family", ipAddress: "1.1.1.3", testState: .untested),
    DNSProvider(name: "OpenDNS", ipAddress: "208.67.222.222", testState: .untested),
    DNSProvider(name: "OpenDNS (secondary)", ipAddress: "208.67.220.220", testState: .untested),
    DNSProvider(name: "OpenDNS FamilyShield", ipAddress: "208.67.222.123", testState: .untested),
    DNSProvider(name: "Quad9", ipAddress: "9.9.9.9", testState: .untested),
    DNSProvider(name: "Quad9 (secondary)", ipAddress: "149.112.112.112", testState: .untested),
    DNSProvider(name: "Quad9 Unsecured", ipAddress: "9.9.9.10", testState: .untested),
    DNSProvider(name: "Comodo Secure DNS", ipAddress: "8.26.56.26", testState: .untested),
    DNSProvider(name: "Comodo Secure DNS (secondary)", ipAddress: "8.20.247.20", testState: .untested),
    DNSProvider(name: "CleanBrowsing", ipAddress: "185.228.168.9", testState: .untested),
    DNSProvider(name: "CleanBrowsing (secondary)", ipAddress: "185.228.169.9", testState: .untested),
    DNSProvider(name: "Yandex DNS", ipAddress: "77.88.8.8", testState: .untested),
    DNSProvider(name: "AdGuard DNS", ipAddress: "94.140.14.14", testState: .untested),
    DNSProvider(name: "AdGuard DNS (secondary)", ipAddress: "94.140.15.15", testState: .untested),
    DNSProvider(name: "AdGuard Family", ipAddress: "94.140.14.15", testState: .untested),
    DNSProvider(name: "AdGuard Non-Filtering", ipAddress: "94.140.14.140", testState: .untested),
    DNSProvider(name: "Mullvad DNS", ipAddress: "194.242.2.2", testState: .untested),
    DNSProvider(name: "dns0.eu", ipAddress: "193.110.81.0", testState: .untested),
    DNSProvider(name: "dns0.eu (secondary)", ipAddress: "185.253.5.0", testState: .untested),
    DNSProvider(name: "Level3", ipAddress: "4.2.2.1", testState: .untested),
    DNSProvider(name: "Level3 (secondary)", ipAddress: "4.2.2.2", testState: .untested),
    DNSProvider(name: "Neustar/UltraDNS", ipAddress: "156.154.70.5", testState: .untested),
    DNSProvider(name: "SafeDNS", ipAddress: "195.46.39.39", testState: .untested),
    DNSProvider(name: "DNS.Watch", ipAddress: "84.200.69.80", testState: .untested),
    DNSProvider(name: "Alternate DNS", ipAddress: "76.76.19.19", testState: .untested),
    DNSProvider(name: "SmartViper", ipAddress: "208.76.50.50", testState: .untested),
    DNSProvider(name: "Dyn", ipAddress: "216.146.35.35", testState: .untested),
    DNSProvider(name: "censurfridns.dk", ipAddress: "91.239.100.100", testState: .untested),
    DNSProvider(name: "Hurricane Electric", ipAddress: "74.82.42.42", testState: .untested),
    DNSProvider(name: "puntCAT", ipAddress: "109.69.8.51", testState: .untested),
    DNSProvider(name: "GreenTeamDNS", ipAddress: "81.218.119.11", testState: .untested),
    DNSProvider(name: "Fourth Estate", ipAddress: "45.77.165.194", testState: .untested),
    DNSProvider(name: "LibreDNS", ipAddress: "116.202.176.26", testState: .untested),
    DNSProvider(name: "OpenNIC", ipAddress: "185.121.177.177", testState: .untested),
    DNSProvider(
      name: "Foundation for Applied Privacy", ipAddress: "185.95.218.42", testState: .untested),
    DNSProvider(name: "NextDNS", ipAddress: "45.90.28.0", testState: .untested),
    DNSProvider(name: "NextDNS (secondary)", ipAddress: "45.90.30.0", testState: .untested),
    DNSProvider(name: "Control D", ipAddress: "76.76.2.0", testState: .untested),
    DNSProvider(name: "Control D (secondary)", ipAddress: "76.76.10.0", testState: .untested),
    DNSProvider(name: "Xiala.net", ipAddress: "77.109.148.136", testState: .untested),
    DNSProvider(name: "Digitalcourage", ipAddress: "46.182.19.48", testState: .untested),
    DNSProvider(name: "Switch", ipAddress: "130.59.31.248", testState: .untested),
    DNSProvider(name: "Applied Privacy", ipAddress: "37.252.185.232", testState: .untested),
    DNSProvider(name: "Keweon", ipAddress: "176.9.93.198", testState: .untested),
    DNSProvider(name: "Firewalla", ipAddress: "185.228.168.168", testState: .untested),
    DNSProvider(name: "BlahDNS", ipAddress: "159.69.198.101", testState: .untested),
    DNSProvider(name: "NixNet DNS", ipAddress: "45.76.113.31", testState: .untested),
    DNSProvider(name: "CIRA Canadian Shield", ipAddress: "149.112.121.10", testState: .untested),
    DNSProvider(name: "Rethink DNS", ipAddress: "185.228.169.9", testState: .untested),
    DNSProvider(name: "LibertyDNS", ipAddress: "209.58.179.186", testState: .untested),
    DNSProvider(name: "Safesurfer", ipAddress: "104.197.28.121", testState: .untested),
    DNSProvider(name: "DNS.SB", ipAddress: "185.222.222.222", testState: .untested),
    DNSProvider(name: "Lightning Wire Labs", ipAddress: "80.241.218.68", testState: .untested),
    DNSProvider(name: "VentraIP", ipAddress: "112.140.180.5", testState: .untested),
    DNSProvider(name: "DE-CIX Public DNS", ipAddress: "194.11.198.10", testState: .untested),
    DNSProvider(name: "Zilore DNS", ipAddress: "103.247.36.36", testState: .untested),
    DNSProvider(name: "Alternate DNS", ipAddress: "198.101.242.72", testState: .untested),
    DNSProvider(name: "SafeServe", ipAddress: "198.54.117.10", testState: .untested),

  ]

  static let defaultWebsiteLists: [WebsiteList] = [
    // Small, diverse set enabled by default: post-warm-up queries mostly
    // measure cached-response RTT, so a dozen domains gives statistically
    // the same median as hundreds — in a fraction of the time.
    WebsiteList(
      name: "Quick Test",
      websites: [
        "https://www.google.com", "https://www.youtube.com", "https://www.facebook.com",
        "https://www.amazon.com", "https://www.wikipedia.org", "https://www.reddit.com",
        "https://www.netflix.com", "https://www.apple.com", "https://www.github.com",
        "https://www.cloudflare.com", "https://www.bbc.com", "https://www.espn.com",
      ], isEnabled: true),

    WebsiteList(
      name: "Search Engines",
      websites: [
        "https://www.google.com", "https://www.bing.com", "https://www.yahoo.com",
        "https://www.duckduckgo.com", "https://www.yandex.com", "https://www.ask.com",
        "https://www.aol.com", "https://www.wolframalpha.com", "https://www.ecosia.org",
        "https://www.searchencrypt.com", "https://www.dogpile.com", "https://www.webcrawler.com",
        "https://www.gibiru.com", "https://www.startpage.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Social Media",
      websites: [
        "https://www.facebook.com", "https://www.twitter.com", "https://www.instagram.com",
        "https://www.pinterest.com", "https://www.linkedin.com", "https://www.reddit.com",
        "https://www.tiktok.com", "https://www.snapchat.com", "https://www.tumblr.com",
        "https://www.flickr.com", "https://www.medium.com", "https://www.discord.com",
        "https://www.telegram.org", "https://www.qq.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Video Platforms",
      websites: [
        "https://www.youtube.com", "https://www.netflix.com", "https://www.vimeo.com",
        "https://www.dailymotion.com", "https://www.twitch.tv", "https://www.hulu.com",
        "https://www.disneyplus.com", "https://www.peacocktv.com", "https://www.crunchyroll.com",
      ], isEnabled: false),

    WebsiteList(
      name: "E-commerce",
      websites: [
        "https://www.amazon.com", "https://www.ebay.com", "https://www.aliexpress.com",
        "https://www.flipkart.com", "https://www.walmart.com", "https://www.target.com",
        "https://www.bestbuy.com", "https://www.etsy.com", "https://www.wayfair.com",
        "https://www.alibaba.com", "https://www.rakuten.com", "https://www.shopify.com",
        "https://www.zalando.com", "https://www.asos.com",
      ], isEnabled: false),

    WebsiteList(
      name: "News and Information",
      websites: [
        "https://www.wikipedia.org", "https://www.nytimes.com", "https://www.bbc.com",
        "https://www.cnn.com", "https://www.foxnews.com", "https://www.theguardian.com",
        "https://www.nbcnews.com", "https://www.cnbc.com", "https://www.aljazeera.com",
        "https://www.usatoday.com", "https://www.washingtonpost.com", "https://www.latimes.com",
        "https://www.huffpost.com", "https://www.wsj.com", "https://www.forbes.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Technology and Tools",
      websites: [
        "https://www.apple.com", "https://www.microsoft.com", "https://www.github.com",
        "https://www.adobe.com", "https://www.oracle.com", "https://www.sap.com",
        "https://www.intuit.com", "https://www.salesforce.com", "https://www.vmware.com",
        "https://www.symantec.com", "https://www.redhat.com", "https://www.autodesk.com",
        "https://www.sas.com", "https://www.tableau.com", "https://www.atlassian.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Online Services",
      websites: [
        "https://www.canva.com", "https://www.zoom.us", "https://www.openai.com",
        "https://www.dropbox.com", "https://www.airbnb.com", "https://www.spotify.com",
        "https://www.uber.com", "https://www.lyft.com", "https://www.slack.com",
        "https://www.squareup.com", "https://www.mailchimp.com", "https://www.docusign.com",
        "https://www.godaddy.com", "https://www.wix.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Health and Wellness",
      websites: [
        "https://www.webmd.com", "https://www.mayoclinic.org", "https://www.nih.gov",
        "https://www.who.int", "https://www.cdc.gov", "https://www.healthline.com",
        "https://www.medicinenet.com", "https://www.drugs.com", "https://www.everydayhealth.com",
        "https://www.verywellhealth.com", "https://www.health.com", "https://www.self.com",
        "https://www.shape.com", "https://www.menshealth.com", "https://www.womenshealthmag.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Education and Learning",
      websites: [
        "https://www.khanacademy.org", "https://www.coursera.org", "https://www.udemy.com",
        "https://www.edx.org", "https://www.skillshare.com", "https://www.lynda.com",
        "https://www.codecademy.com", "https://www.udacity.com", "https://www.alison.com",
        "https://www.credly.com", "https://www.skillsoft.com", "https://www.pluralsight.com",
        "https://www.simplilearn.com", "https://www.edutopia.org",
      ], isEnabled: false),

    WebsiteList(
      name: "Entertainment and Fun",
      websites: [
        "https://www.imdb.com", "https://www.rottentomatoes.com", "https://www.metacritic.com",
        "https://www.gamespot.com", "https://www.polygon.com", "https://www.ign.com",
        "https://www.ea.com", "https://www.rockstargames.com", "https://www.nintendo.com",
        "https://www.playstation.com", "https://www.xbox.com", "https://www.epicgames.com",
        "https://www.unity.com", "https://www.unrealengine.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Sports and Fitness",
      websites: [
        "https://www.espn.com", "https://www.nba.com", "https://www.nfl.com", "https://www.mlb.com",
        "https://www.nhl.com", "https://www.olympic.org", "https://www.fifa.com",
        "https://www.uefa.com", "https://www.nascar.com", "https://www.ironman.com",
        "https://www.runnersworld.com", "https://www.bicycling.com", "https://www.skimag.com",
        "https://www.surfer.com", "https://www.golfdigest.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Travel and Tourism",
      websites: [
        "https://www.booking.com", "https://www.expedia.com", "https://www.airbnb.com",
        "https://www.tripadvisor.com", "https://www.kayak.com", "https://www.skyscanner.com",
        "https://www.hotels.com", "https://www.trivago.com", "https://www.lonelyplanet.com",
        "https://www.fodors.com", "https://www.frommers.com", "https://www.ricksteves.com",
        "https://www.nomadicmatt.com", "https://www.travelandleisure.com",
        "https://www.cntraveler.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Food and Cooking",
      websites: [
        "https://www.allrecipes.com", "https://www.foodnetwork.com", "https://www.epicurious.com",
        "https://www.bonappetit.com", "https://www.seriouseats.com",
        "https://www.simplyrecipes.com", "https://www.thespruceeats.com", "https://www.eater.com",
        "https://www.chowhound.com", "https://www.food52.com", "https://www.loveandlemons.com",
        "https://www.skinnytaste.com", "https://www.budgetbytes.com",
        "https://www.smittenkitchen.com", "https://www.101cookbooks.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Shopping and Fashion",
      websites: [
        "https://www.shopify.com", "https://www.etsy.com", "https://www.zalando.com",
        "https://www.asos.com", "https://www.amazon.com", "https://www.ebay.com",
        "https://www.aliexpress.com", "https://www.flipkart.com", "https://www.walmart.com",
        "https://www.target.com", "https://www.bestbuy.com", "https://www.alibaba.com",
        "https://www.rakuten.com", "https://www.newegg.com", "https://www.wayfair.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Business and Finance",
      websites: [
        "https://www.bloomberg.com", "https://www.wsj.com", "https://www.forbes.com",
        "https://www.barrons.com", "https://www.businessinsider.com", "https://www.fool.com",
        "https://www.cnbc.com", "https://www.marketwatch.com", "https://www.investopedia.com",
        "https://www.kiplinger.com", "https://www.money.com", "https://www.fortune.com",
        "https://www.inc.com", "https://www.entrepreneur.com", "https://www.fastcompany.com",
      ], isEnabled: false),

    WebsiteList(
      name: "Science and Nature",
      websites: [
        "https://www.nationalgeographic.com", "https://www.scientificamerican.com",
        "https://www.nature.com", "https://www.sciencedaily.com", "https://www.livescience.com",
        "https://www.space.com", "https://www.astronomy.com", "https://www.discovermagazine.com",
        "https://www.popsci.com", "https://www.newscientist.com", "https://www.quantamagazine.org",
        "https://www.sciencenews.org",
      ], isEnabled: false),

    WebsiteList(name: "User List", websites: [], isEnabled: false),
  ]

  @State private var showingSettings = false
  @State private var isTesting = false
  @State private var testTask: Task<Void, Never>? = nil
  @State private var completedQueries = 0
  @State private var totalQueries = 0
  @State private var selectedProvider: DNSProvider?

  /// How many times each (provider, domain) pair is queried per run.
  private static let repetitions = 3
  /// How many cache-busting (uncached) queries each provider gets per run.
  private static let uncachedRepetitions = 3
  /// A provider whose first N queries all time out is marked unresponsive
  /// and skipped for the rest of the run.
  private static let deadAfterFailures = 3

  


  var body: some View {
    let ranks = testedRankMap(sortedProviders)

    VStack(spacing: 0) {
      List {
        ForEach(sortedProviders, id: \.id)			{ provider in
          ProviderRow(provider: provider, rank: ranks[provider.id])
            .contentShape(Rectangle())
            .onTapGesture {
              if !provider.samples.isEmpty {
                selectedProvider = provider
              }
            }
        }
      }
      .listStyle(.inset(alternatesRowBackgrounds: true))
      .safeAreaInset(edge: .bottom) {
        bottomBar
      }
    }
    .frame(minWidth: 360)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          isTesting ? stopTesting() : startTesting()
        } label: {
          Label(isTesting ? "Stop" : "Test", systemImage: isTesting ? "stop.fill" : "bolt.fill")
        }
        .help(isTesting ? "Stop testing" : "Test all enabled resolvers")
      }
      ToolbarItem {
        Button {
          showingSettings = true
        } label: {
          Label("Settings", systemImage: "gearshape")
        }
        .help("Settings")
      }
    }
    .onChange(of: showingSettings) { _, isShowing in
      // Editing providers/sites while a test is running would invalidate results.
      stopTesting()
      // Persist any edits made in Settings when it closes.
      if !isShowing {
        Persistence.save(providers: dnsProviders, lists: websiteLists)
      }
    }
    .sheet(isPresented: $showingSettings) {
      SettingsView(dnsProviders: $dnsProviders, websiteLists: $websiteLists)
        .frame(
          minWidth: 360, idealWidth: 380, maxWidth: .infinity, minHeight: 320, idealHeight: 440,
          maxHeight: .infinity)
    }
    .sheet(item: $selectedProvider) { provider in
      ProviderStatsView(provider: provider)
        .frame(width: 300, height: 640)
    }
  }

  /// Live leaderboard order: providers with a result first (sorted by speed,
  /// updating as samples arrive mid-run), then in-flight ones, then untested,
  /// with unresponsive resolvers at the bottom.
  private var sortedProviders: [DNSProvider] {
    dnsProviders.sorted { lhs, rhs in
      let lhsGroup = sortGroup(lhs)
      let rhsGroup = sortGroup(rhs)
      if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }
      if lhsGroup == 0, lhs.speed != rhs.speed {
        return (lhs.speed ?? .infinity) < (rhs.speed ?? .infinity)
      }
      return lhs.name < rhs.name
    }
  }

  private func sortGroup(_ provider: DNSProvider) -> Int {
    if provider.speed != nil { return 0 }
    switch provider.testState {
    case .testing: return 1
    case .untested: return 2
    case .tested: return 3  // tested but no response
    }
  }

  /// Assigns 1-based ranks to providers that produced a result, in sorted order.
  private func testedRankMap(_ sorted: [DNSProvider]) -> [UUID: Int] {
    var map: [UUID: Int] = [:]
    var rank = 1
    for provider in sorted where provider.speed != nil {
      map[provider.id] = rank
      rank += 1
    }
    return map
  }

  private var enabledCount: Int {
    dnsProviders.filter { $0.isEnabled }.count
  }

  @ViewBuilder private var bottomBar: some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: 8) {
        if isTesting {
          ProgressView(value: Double(completedQueries), total: Double(max(totalQueries, 1)))
            .frame(width: 130)
          Text("Testing… \(completedQueries) of \(totalQueries) queries")
        } else {
          Image(systemName: "network")
          Text("\(enabledCount) resolver\(enabledCount == 1 ? "" : "s") enabled")
        }
        Spacer()
        if isTesting {
          Button("Stop") { stopTesting() }
            .controlSize(.small)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(.bar)
    }
  }

  /// Derives the hostnames to resolve from the enabled website lists.
  private func activeDomains() -> [String] {
    let urls = websiteLists.filter { $0.isEnabled }.flatMap { $0.websites }
    var seen = Set<String>()
    var hosts: [String] = []
    for urlString in urls {
      guard let host = URL(string: urlString)?.host, !host.isEmpty else { continue }
      if seen.insert(host).inserted {
        hosts.append(host)
      }
    }
    return hosts
  }

  private func stopTesting() {
    testTask?.cancel()
    testTask = nil
    isTesting = false
    finalizeInFlightProviders()
  }

  /// Settles any provider still marked `.testing`: keeps partial results if it
  /// produced (or attempted) anything, otherwise returns it to `.untested`.
  private func finalizeInFlightProviders() {
    for index in dnsProviders.indices where dnsProviders[index].testState == .testing {
      let started = dnsProviders[index].attempts > 0 || dnsProviders[index].coldStart != nil
      dnsProviders[index].testState = started ? .tested : .untested
    }
  }

  private func startTesting() {
    testTask?.cancel()
    isTesting = true
    testTask = Task { await runTests() }
  }

  // Queries are serialized (one in flight at a time) so nothing competes for
  // the local uplink, but ordered round-robin across providers so that
  // time-varying network conditions add the same noise to every provider's
  // sample set instead of biasing whichever was tested last.
  @MainActor
  private func runTests() async {
    defer {
      isTesting = false
      finalizeInFlightProviders()
    }

    let domains = activeDomains()
    let activeIndices = dnsProviders.indices.filter { dnsProviders[$0].isEnabled }
    guard !domains.isEmpty, !activeIndices.isEmpty else { return }

    for index in activeIndices {
      dnsProviders[index].testState = .testing
      dnsProviders[index].speed = nil
      dnsProviders[index].fastest = nil
      dnsProviders[index].slowest = nil
      dnsProviders[index].coldStart = nil
      dnsProviders[index].samples = []
      dnsProviders[index].attempts = 0
      dnsProviders[index].uncachedSpeed = nil
      dnsProviders[index].uncachedSamples = []
      dnsProviders[index].uncachedAttempts = 0
    }

    let perProvider = 1 + domains.count * Self.repetitions + Self.uncachedRepetitions
    totalQueries = activeIndices.count * perProvider
    completedQueries = 0

    var remaining = [Int: Int](uniqueKeysWithValues: activeIndices.map { ($0, perProvider) })
    var attemptCount: [Int: Int] = [:]
    var successCount: [Int: Int] = [:]
    var dead = Set<Int>()

    func recordCompletion(_ index: Int) {
      completedQueries += 1
      remaining[index, default: 0] -= 1
    }

    // Unresponsive resolvers are dropped early so their 2s timeouts don't
    // dominate the run; their remaining queries are credited to progress.
    func markDeadIfNeeded(_ index: Int) {
      guard !dead.contains(index),
        attemptCount[index, default: 0] >= Self.deadAfterFailures,
        successCount[index, default: 0] == 0
      else { return }
      dead.insert(index)
      dnsProviders[index].testState = .tested  // speed stays nil -> "No response"
      completedQueries += max(0, remaining[index, default: 0])
      remaining[index] = 0
    }

    // Warm-up round: primes each resolver's path; the time is reported
    // separately as cold start and excluded from the stats.
    for index in activeIndices {
      if Task.isCancelled { return }
      let t = await DNSResolver.query(server: dnsProviders[index].ipAddress, domain: domains[0])
      if Task.isCancelled { return }
      dnsProviders[index].coldStart = t
      attemptCount[index, default: 0] += 1
      if t != nil { successCount[index, default: 0] += 1 }
      recordCompletion(index)
      markDeadIfNeeded(index)
    }

    // Cached rounds: these mostly hit the resolver's cache, so the median
    // reflects network round-trip latency to the resolver.
    for _ in 0..<Self.repetitions {
      for domain in domains {
        for index in activeIndices where !dead.contains(index) {
          if Task.isCancelled { return }
          let t = await DNSResolver.query(server: dnsProviders[index].ipAddress, domain: domain)
          if Task.isCancelled { return }
          dnsProviders[index].attempts += 1
          attemptCount[index, default: 0] += 1
          if let t {
            successCount[index, default: 0] += 1
            dnsProviders[index].samples.append(t)
            let sorted = dnsProviders[index].samples.sorted()
            dnsProviders[index].fastest = sorted.first
            dnsProviders[index].slowest = sorted.last
            // Median is robust to occasional outliers/jitter, unlike the mean.
            dnsProviders[index].speed = DNSResolver.median(of: sorted)
          }
          recordCompletion(index)
          markDeadIfNeeded(index)
        }
      }
    }

    // Cache-busting rounds: random subdomains no resolver can have cached
    // force a full recursive lookup, measuring upstream resolution speed.
    // Longer timeout since recursion is inherently slower than a cache hit.
    for rep in 0..<Self.uncachedRepetitions {
      let base = domains[rep % domains.count]
      for index in activeIndices where !dead.contains(index) {
        if Task.isCancelled { return }
        let host = DNSResolver.cacheBustingHost(base: base)
        let t = await DNSResolver.query(
          server: dnsProviders[index].ipAddress, domain: host, timeout: 3.0)
        if Task.isCancelled { return }
        dnsProviders[index].uncachedAttempts += 1
        if let t {
          dnsProviders[index].uncachedSamples.append(t)
          dnsProviders[index].uncachedSpeed = DNSResolver.median(
            of: dnsProviders[index].uncachedSamples)
        }
        recordCompletion(index)
      }
    }
  }

}

// A single resolver row: leading status/rank indicator, name + IP, and the
// color-coded latency with a min–max range underneath.
struct ProviderRow: View {
  let provider: DNSProvider
  let rank: Int?

  var body: some View {
    HStack(spacing: 10) {
      statusIndicator
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 1) {
        Text(provider.name)
          .fontWeight(.medium)
          .lineLimit(1)
        Text(provider.ipAddress)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 1) {
        Text(speedText)
          .monospacedDigit()
          .foregroundStyle(speedColor)
        if let detail = detailText {
          Text(detail)
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
        }
      }
      Image(systemName: "chevron.right")
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .opacity(provider.samples.isEmpty ? 0 : 1)
    }
    .padding(.vertical, 3)
  }

  @ViewBuilder private var statusIndicator: some View {
    // Rank appears as soon as the provider has a live median, even mid-run.
    if let rank {
      Text("\(rank)")
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(.secondary)
    } else {
      switch provider.testState {
      case .untested:
        Circle().fill(Color.secondary.opacity(0.25)).frame(width: 8, height: 8)
      case .testing:
        ProgressView().controlSize(.small).scaleEffect(0.7)
      case .tested:
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.caption2)
          .foregroundStyle(.orange)
      }
    }
  }

  private func fmt(_ t: TimeInterval) -> String { String(format: "%.0f", t * 1000) }

  private var detailText: String? {
    var parts: [String] = []
    if let fastest = provider.fastest, let slowest = provider.slowest {
      parts.append("\(fmt(fastest))–\(fmt(slowest)) ms")
    }
    if let uncached = provider.uncachedSpeed {
      parts.append("uncached \(fmt(uncached)) ms")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private var speedText: String {
    switch provider.testState {
    case .untested: return "—"
    case .testing:
      if let speed = provider.speed { return String(format: "%.1f ms", speed * 1000) }
      return "Testing…"
    case .tested:
      if let speed = provider.speed { return String(format: "%.1f ms", speed * 1000) }
      return "No response"
    }
  }

  private var speedColor: Color {
    if provider.testState == .untested { return .secondary }
    guard let speed = provider.speed else {
      return provider.testState == .tested ? .orange : .secondary
    }
    let ms = speed * 1000
    if ms < 40 { return .green }
    if ms < 100 { return Color(red: 0.85, green: 0.6, blue: 0.0) }
    return .red
  }
}

// Detailed per-provider statistics, shown when a tested provider is tapped.
struct ProviderStatsView: View {
  let provider: DNSProvider
  @Environment(\.presentationMode) var presentationMode

  private func ms(_ t: TimeInterval?) -> String {
    guard let t = t else { return "—" }
    return String(format: "%.1f ms", t * 1000)
  }

  var body: some View {
    let samples = provider.samples
    let success = samples.count
    let attempts = provider.attempts
    let timeouts = max(0, attempts - success)
    let reliability = attempts > 0 ? Double(success) / Double(attempts) * 100 : 0
    let mean = DNSResolver.mean(of: samples)
    let stdDev = DNSResolver.standardDeviation(of: samples)
    let p25 = DNSResolver.percentile(25, of: samples)
    let p75 = DNSResolver.percentile(75, of: samples)

    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 2) {
        Text(provider.name).font(.title2).bold()
        Text(provider.ipAddress)
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
      .padding([.horizontal, .top], 16)
      .padding(.bottom, 4)
      .frame(maxWidth: .infinity, alignment: .leading)

      Form {
        Section(header: Text("Central tendency")) {
          StatRow(label: "Median (p50)", value: ms(DNSResolver.median(of: samples)))
          StatRow(label: "Mean", value: ms(mean))
          StatRow(label: "Mode (≈)", value: ms(DNSResolver.mode(of: samples)))
        }
        Section(header: Text("Spread")) {
          StatRow(label: "Fastest (min)", value: ms(provider.fastest))
          StatRow(label: "Slowest (max)", value: ms(provider.slowest))
          StatRow(label: "Range", value: ms(range(provider.fastest, provider.slowest)))
          StatRow(label: "Std deviation", value: ms(stdDev))
          StatRow(label: "Jitter (CV)", value: cv(stdDev, mean))
          StatRow(label: "IQR (p25–p75)", value: ms(range(p25, p75)))
        }
        Section(header: Text("Percentiles")) {
          StatRow(label: "90th", value: ms(DNSResolver.percentile(90, of: samples)))
          StatRow(label: "95th", value: ms(DNSResolver.percentile(95, of: samples)))
          StatRow(label: "99th", value: ms(DNSResolver.percentile(99, of: samples)))
        }
        Section(header: Text("Uncached resolution")) {
          StatRow(label: "Median", value: ms(DNSResolver.median(of: provider.uncachedSamples)))
          StatRow(label: "Fastest", value: ms(provider.uncachedSamples.min()))
          StatRow(label: "Slowest", value: ms(provider.uncachedSamples.max()))
          StatRow(
            label: "Successful queries",
            value: "\(provider.uncachedSamples.count) / \(provider.uncachedAttempts)")
        }
        Section(header: Text("Reliability")) {
          StatRow(label: "Cold start (warm-up)", value: ms(provider.coldStart))
          StatRow(label: "Successful queries", value: "\(success) / \(attempts)")
          StatRow(label: "Timeouts", value: "\(timeouts)")
          StatRow(label: "Response rate", value: String(format: "%.0f%%", reliability))
        }
      }
      .formStyle(.grouped)

      Divider()
      HStack {
        Spacer()
        Button("Done") { presentationMode.wrappedValue.dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding(12)
    }
  }

  /// Difference between two optional times (e.g. max - min), or nil.
  private func range(_ low: TimeInterval?, _ high: TimeInterval?) -> TimeInterval? {
    guard let low = low, let high = high else { return nil }
    return high - low
  }

  /// Coefficient of variation (std dev / mean), formatted as a percentage.
  private func cv(_ stdDev: TimeInterval?, _ mean: TimeInterval?) -> String {
    guard let stdDev = stdDev, let mean = mean, mean > 0 else { return "—" }
    return String(format: "%.0f%%", stdDev / mean * 100)
  }
}

struct StatRow: View {
  let label: String
  let value: String
  var body: some View {
    LabeledContent(label) {
      Text(value)
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
  }
}

struct SettingsView: View {
  @Binding var dnsProviders: [DNSProvider]
  @Binding var websiteLists: [WebsiteList]
  @Environment(\.presentationMode) var presentationMode

  @State private var newDNSName: String = ""
  @State private var newDNSIp: String = ""
  @State private var newWebsite: String = ""
  @State private var selectedWebsiteListIndex: Int = 0
  @State private var selectedTab: Tab = .add
  @State private var isAllWebsitesEnabled: Bool = true
  @State private var isAllDNSProvidersEnabled: Bool = true

  private var currentDNSServers: [String] {
    getCurrentDNSServers()
  }

  enum Tab {
    case add, manageSites, manageDNS, System
  }

  init(
    dnsProviders: Binding<[DNSProvider]>, websiteLists: Binding<[WebsiteList]>
  ) {
    self._dnsProviders = dnsProviders
    self._websiteLists = websiteLists
    if let userListIndex = websiteLists.wrappedValue.firstIndex(where: { $0.name == "User List" }) {
      self._selectedWebsiteListIndex = State(initialValue: userListIndex)
    } else {
      self._selectedWebsiteListIndex = State(initialValue: 0)  // Fallback to the first index if not found
    }
  }

  var body: some View {
    VStack {
      TabView(selection: $selectedTab) {
        VStack {
          Section(header: Text("Current DNS Server: " + currentDNSServers.joined(separator: ", ")))
          {
          }
          Button("Add Current DNS Server") {
            for dns in currentDNSServers {
              if !dnsProviders.contains(where: { $0.ipAddress == dns }) {
                let newDNS = DNSProvider(name: "*Current DNS", ipAddress: dns, testState: .untested)
                $dnsProviders.wrappedValue.append(newDNS)
              }
            }
          }
          Form {
            Section(header: Text("Add DNS Provider")) {
              HStack {
                Text("Name:")
                CustomTextField(text: $newDNSName, placeholder: "ExampleDNS")
              }
              HStack {
                Text("IP:")
                CustomTextField(text: $newDNSIp, placeholder: "127.0.0.1")
              }
              Button("Add") {
                if !newDNSName.isEmpty && !newDNSIp.isEmpty && isValidIPAddress(ipAddress: newDNSIp)
                {
                  let newDNS = DNSProvider(
                    name: newDNSName, ipAddress: newDNSIp, testState: .untested)
                  $dnsProviders.wrappedValue.append(newDNS)
                  newDNSName = ""
                  newDNSIp = ""
                } else {
                  // Don't add
                }
              }
            }
            Section(header: Text("Add Website")) {
              Picker("Website List", selection: $selectedWebsiteListIndex) {
                ForEach($websiteLists.wrappedValue.indices, id: \.self) { index in
                  Text($websiteLists.wrappedValue[index].name).tag(index)
                }
              }
              HStack {
                Text("URL:")
                CustomTextField(text: $newWebsite, placeholder: "https://www.kyllan.dev")
              }
              Button("Add") {
                if !newWebsite.isEmpty && isValidURL(url: newWebsite) {
                  $websiteLists.wrappedValue[selectedWebsiteListIndex].websites.append(newWebsite)
                  newWebsite = ""
                  //enable the user list when a new website is added
                  $websiteLists.wrappedValue[selectedWebsiteListIndex].isEnabled = true
                } else {
                  // Don't add
                }
              }
            }
          }
        }
        .tabItem {
          Label("Add", systemImage: "plus")
        }
        .tag(Tab.add)

        VStack {
          List {
            Toggle("Toggle All", isOn: $isAllWebsitesEnabled)
              .onChange(of: isAllWebsitesEnabled) {
                for index in websiteLists.indices {
                  websiteLists[index].isEnabled = isAllWebsitesEnabled
                }
              }

            ForEach(websiteLists.indices, id: \.self) { index in
              HStack {
                Toggle("", isOn: $websiteLists[index].isEnabled)
                VStack(alignment: .leading) {
                  Text(websiteLists[index].name)
                  ForEach(websiteLists[index].websites, id: \.self) { website in
                    Text(website)
                      .font(.caption)
                      .foregroundColor(.gray)
                  }
                }
              }
            }
          }
        }
        .tabItem {
          Label("Manage Websites", systemImage: "gearshape")
        }
        .tag(Tab.manageSites)

        VStack {
          List {
            Toggle(isOn: $isAllDNSProvidersEnabled) {
              Text("Toggle All")
            }
            .onChange(of: isAllDNSProvidersEnabled) {
              for index in dnsProviders.indices {
                dnsProviders[index].isEnabled = isAllDNSProvidersEnabled
              }
            }

            ForEach(dnsProviders.indices, id: \.self) { index in
              HStack {
                Toggle(dnsProviders[index].name, isOn: $dnsProviders[index].isEnabled)
                Spacer()
                Text(dnsProviders[index].ipAddress)
                  .font(.caption)
                  .foregroundColor(.gray)
              }
            }
          }
        }
        .tabItem {
          Label("Manage DNS", systemImage: "gearshape")
        }
        .tag(Tab.manageDNS)

        VStack(alignment: .leading, spacing: 12) {
          Text("How testing works").font(.headline)
          Text(
            "Each resolver is sent raw UDP DNS queries (port 53) directly to its IP address — the same method as `dig @<server>`. Queries run one at a time so nothing competes for your connection, but rotate round-robin across resolvers so changing network conditions affect everyone equally. A warm-up query per resolver is discarded, and resolvers that fail their first few queries are marked unresponsive and skipped."
          ).font(.caption).foregroundColor(.gray)
          Text(
            "The main figure is the median round-trip time for repeated lookups, which are mostly served from the resolver's cache — effectively your network latency to that resolver. A separate cache-busting pass queries random subdomains no resolver can have cached, measuring true upstream resolution speed (shown as \"uncached\"). Results update live as samples arrive."
          ).font(.caption).foregroundColor(.gray)
          Spacer()
        }.padding().tabItem {
          Label("System", systemImage: "gearshape")
        }.tag(Tab.System)

      }.padding( /*@START_MENU_TOKEN@*/10 /*@END_MENU_TOKEN@*/)
      Button("Close") {
        presentationMode.wrappedValue.dismiss()
      }
    }.padding(.bottom)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView(
      dnsProviders: .constant([]), websiteLists: .constant([]))
  }
}
