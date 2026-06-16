//
//  DNSResolver.swift
//  DNS-speed-checker
//
//  Measures DNS resolution speed by sending a raw UDP DNS query directly to a
//  specific resolver IP (like `dig @<ip> <domain>`) and timing the round trip.
//  This is what makes per-provider results meaningful: URLSession always uses
//  the system resolver, so it could never compare individual DNS servers.
//

import Foundation
import Network

enum DNSResolver {

  /// Builds a minimal DNS query packet for an A record of `domain`.
  static func buildQuery(domain: String) -> Data {
    var data = Data()
    let id = UInt16.random(in: 0...UInt16.max)
    data.append(UInt8(id >> 8))
    data.append(UInt8(id & 0xFF))
    data.append(0x01)
    data.append(0x00)  // flags: standard query, recursion desired
    data.append(0x00)
    data.append(0x01)  // QDCOUNT = 1
    data.append(0x00)
    data.append(0x00)  // ANCOUNT
    data.append(0x00)
    data.append(0x00)  // NSCOUNT
    data.append(0x00)
    data.append(0x00)  // ARCOUNT

    for label in domain.split(separator: ".") {
      let bytes = Array(label.utf8)
      data.append(UInt8(bytes.count))
      data.append(contentsOf: bytes)
    }
    data.append(0x00)  // end of QNAME
    data.append(0x00)
    data.append(0x01)  // QTYPE = A
    data.append(0x00)
    data.append(0x01)  // QCLASS = IN
    return data
  }

  /// Sends a single DNS query to `server` for `domain` over UDP:53 and returns
  /// the round-trip time in seconds, or nil on timeout/error.
  static func query(server: String, domain: String, timeout: TimeInterval = 2.0) async
    -> TimeInterval?
  {
    await withCheckedContinuation { (cont: CheckedContinuation<TimeInterval?, Never>) in
      guard let port = NWEndpoint.Port(rawValue: 53) else {
        cont.resume(returning: nil)
        return
      }
      let connection = NWConnection(host: NWEndpoint.Host(server), port: port, using: .udp)
      let start = DispatchTime.now()
      let lock = NSLock()
      var finished = false

      func finish(_ result: TimeInterval?) {
        lock.lock()
        defer { lock.unlock() }
        if finished { return }
        finished = true
        connection.cancel()
        cont.resume(returning: result)
      }

      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          let packet = buildQuery(domain: domain)
          connection.send(
            content: packet,
            completion: .contentProcessed { error in
              if error != nil {
                finish(nil)
                return
              }
              connection.receiveMessage { data, _, _, recvError in
                if recvError != nil || data == nil || data!.isEmpty {
                  finish(nil)
                  return
                }
                let elapsed =
                  Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)
                  / 1_000_000_000
                finish(elapsed)
              }
            })
        case .failed, .cancelled:
          finish(nil)
        default:
          break
        }
      }

      connection.start(queue: .global(qos: .userInitiated))
      DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
    }
  }

  // MARK: - Cache busting

  /// Random DNS-safe label, e.g. "k3xq9f0a2bzm".
  static func randomLabel(length: Int = 12) -> String {
    let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    return String((0..<length).map { _ in chars.randomElement()! })
  }

  /// A hostname no resolver can have cached: a random subdomain of `base`.
  /// The answer is NXDOMAIN, but the round-trip time measures the resolver's
  /// full upstream (recursive) resolution path rather than a cache hit.
  static func cacheBustingHost(base: String) -> String {
    "\(randomLabel()).\(base)"
  }

  // MARK: - Statistics helpers

  /// Median of a list of samples, or nil if empty.
  static func median(of samples: [TimeInterval]) -> TimeInterval? {
    guard !samples.isEmpty else { return nil }
    let sorted = samples.sorted()
    let mid = sorted.count / 2
    if sorted.count % 2 == 0 {
      return (sorted[mid - 1] + sorted[mid]) / 2
    }
    return sorted[mid]
  }

  /// Arithmetic mean, or nil if empty.
  static func mean(of samples: [TimeInterval]) -> TimeInterval? {
    guard !samples.isEmpty else { return nil }
    return samples.reduce(0, +) / Double(samples.count)
  }

  /// Population standard deviation, or nil if empty.
  static func standardDeviation(of samples: [TimeInterval]) -> TimeInterval? {
    guard let mean = mean(of: samples), !samples.isEmpty else { return nil }
    let variance = samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count)
    return variance.squareRoot()
  }

  /// Mode of the samples after rounding to the nearest millisecond, in seconds.
  /// Returns the most frequent rounded value (nil if empty).
  static func mode(of samples: [TimeInterval]) -> TimeInterval? {
    guard !samples.isEmpty else { return nil }
    var counts: [Int: Int] = [:]
    for s in samples {
      let ms = Int((s * 1000).rounded())
      counts[ms, default: 0] += 1
    }
    guard let best = counts.max(by: { $0.value < $1.value })?.key else { return nil }
    return Double(best) / 1000
  }

  /// The `p`-th percentile (0...100) using nearest-rank, or nil if empty.
  static func percentile(_ p: Double, of samples: [TimeInterval]) -> TimeInterval? {
    guard !samples.isEmpty else { return nil }
    let sorted = samples.sorted()
    let rank = Int((p / 100 * Double(sorted.count)).rounded(.up)) - 1
    let clamped = min(max(rank, 0), sorted.count - 1)
    return sorted[clamped]
  }
}
