//
//  DNS_speed_checkerTests.swift
//  DNS-speed-checkerTests
//
//  Created by Kyllan Wunder on 5/5/24.
//

import XCTest

@testable import DNS_speed_checker

final class DNS_speed_checkerTests: XCTestCase {

  // MARK: - DNS query packet construction

  func testQueryPacketLength() throws {
    // 12-byte header + (1+6)+(1+3)+1 QNAME + 4 (QTYPE+QCLASS) = 28 bytes.
    let packet = DNSResolver.buildQuery(domain: "google.com")
    XCTAssertEqual(packet.count, 28)
  }

  func testQueryHeaderFlagsAndCounts() throws {
    let packet = [UInt8](DNSResolver.buildQuery(domain: "example.com"))
    // Bytes 0-1 are a random ID, so only check the rest of the header.
    XCTAssertEqual(packet[2], 0x01, "Recursion-desired flag")
    XCTAssertEqual(packet[3], 0x00)
    XCTAssertEqual(packet[4], 0x00)
    XCTAssertEqual(packet[5], 0x01, "QDCOUNT should be 1")
    XCTAssertEqual(packet[6], 0x00)
    XCTAssertEqual(packet[7], 0x00, "ANCOUNT should be 0")
  }

  func testQueryNameEncoding() throws {
    let packet = [UInt8](DNSResolver.buildQuery(domain: "google.com"))
    // QNAME starts at byte 12: length-prefixed labels, terminated by 0x00.
    XCTAssertEqual(packet[12], 6)  // "google"
    XCTAssertEqual(Array(packet[13...18]), Array("google".utf8))
    XCTAssertEqual(packet[19], 3)  // "com"
    XCTAssertEqual(Array(packet[20...22]), Array("com".utf8))
    XCTAssertEqual(packet[23], 0)  // end of QNAME
    // QTYPE = A (1), QCLASS = IN (1)
    XCTAssertEqual(Array(packet[24...27]), [0x00, 0x01, 0x00, 0x01])
  }

  func testQueryGeneratesUniqueIDs() throws {
    // Different calls should (almost always) use different random IDs.
    var ids = Set<UInt16>()
    for _ in 0..<50 {
      let p = [UInt8](DNSResolver.buildQuery(domain: "a.com"))
      ids.insert(UInt16(p[0]) << 8 | UInt16(p[1]))
    }
    XCTAssertGreaterThan(ids.count, 1)
  }

  // MARK: - Median aggregation

  func testMedianOddCount() throws {
    let m = try XCTUnwrap(DNSResolver.median(of: [0.003, 0.001, 0.002]))
    XCTAssertEqual(m, 0.002, accuracy: 1e-9)
  }

  func testMedianEvenCount() throws {
    let m = try XCTUnwrap(DNSResolver.median(of: [0.004, 0.001, 0.002, 0.003]))
    XCTAssertEqual(m, 0.0025, accuracy: 1e-9)
  }

  func testMedianSingle() throws {
    let m = try XCTUnwrap(DNSResolver.median(of: [0.042]))
    XCTAssertEqual(m, 0.042, accuracy: 1e-9)
  }

  func testMedianEmptyIsNil() throws {
    XCTAssertNil(DNSResolver.median(of: []))
  }

  func testMedianIgnoresOrder() throws {
    let a = DNSResolver.median(of: [0.01, 0.02, 0.03, 0.04, 0.05])
    let b = DNSResolver.median(of: [0.05, 0.01, 0.04, 0.02, 0.03])
    XCTAssertEqual(a, b)
  }

  // MARK: - Other statistics

  func testMean() throws {
    let m = try XCTUnwrap(DNSResolver.mean(of: [0.002, 0.004, 0.006]))
    XCTAssertEqual(m, 0.004, accuracy: 1e-9)
  }

  func testStandardDeviationOfConstantIsZero() throws {
    let sd = try XCTUnwrap(DNSResolver.standardDeviation(of: [0.005, 0.005, 0.005]))
    XCTAssertEqual(sd, 0, accuracy: 1e-9)
  }

  func testStandardDeviationKnownValue() throws {
    // Population std dev of [2,4,4,4,5,5,7,9] ms = 2 ms.
    let samples = [0.002, 0.004, 0.004, 0.004, 0.005, 0.005, 0.007, 0.009]
    let sd = try XCTUnwrap(DNSResolver.standardDeviation(of: samples))
    XCTAssertEqual(sd, 0.002, accuracy: 1e-9)
  }

  func testModePicksMostFrequentMillisecond() throws {
    let mode = try XCTUnwrap(DNSResolver.mode(of: [0.010, 0.0104, 0.020, 0.030]))
    XCTAssertEqual(mode, 0.010, accuracy: 1e-9)  // 10ms appears twice (rounded)
  }

  func testPercentile95() throws {
    let samples = (1...100).map { Double($0) / 1000 }  // 1ms ... 100ms
    let p95 = try XCTUnwrap(DNSResolver.percentile(95, of: samples))
    XCTAssertEqual(p95, 0.095, accuracy: 1e-9)
  }

  func testStatsEmptyAreNil() throws {
    XCTAssertNil(DNSResolver.mean(of: []))
    XCTAssertNil(DNSResolver.standardDeviation(of: []))
    XCTAssertNil(DNSResolver.mode(of: []))
    XCTAssertNil(DNSResolver.percentile(95, of: []))
  }
}
