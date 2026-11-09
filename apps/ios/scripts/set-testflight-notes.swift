#!/usr/bin/env swift
// Sets a TestFlight build's "What to Test" text through the App Store Connect API.
//
//   swift apps/ios/scripts/set-testflight-notes.swift <notes file> <marketing version> <build number>
//
// Needs an App Store Connect API key with the App Manager role: ASC_KEY_ID, ASC_ISSUER_ID and
// ASC_KEY_PATH (path to AuthKey_XXXX.p8), the same variables apps/ios/scripts/testflight.sh uses.
// Waits for the uploaded build to finish processing (up to ASC_WAIT_MINUTES, default 30),
// then writes the notes for the app's primary language, replacing any already there.
// Exits non-zero if it couldn't; the upload itself is unaffected.

import CryptoKit
import Foundation

let bundleID = "__BUNDLE_ID__"
let api = URL(string: "https://api.appstoreconnect.apple.com/v1/")!

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func log(_ message: String) { print("==> \(message)") }

let args = CommandLine.arguments
guard args.count == 4 else { fail("usage: set-testflight-notes.swift <notes file> <marketing version> <build number>") }
let env = ProcessInfo.processInfo.environment
guard let keyID = env["ASC_KEY_ID"], !keyID.isEmpty,
      let issuerID = env["ASC_ISSUER_ID"], !issuerID.isEmpty,
      let keyPath = env["ASC_KEY_PATH"], !keyPath.isEmpty
else { fail("ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH must be set") }

guard let notes = try? String(contentsOfFile: args[1], encoding: .utf8)
    .trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty
else { fail("no notes in \(args[1])") }
let marketing = args[2], build = args[3]
let waitMinutes = Double(env["ASC_WAIT_MINUTES"] ?? "") ?? 30

// MARK: - Token

guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8),
      let key = try? P256.Signing.PrivateKey(pemRepresentation: pem)
else { fail("couldn't read the API key at \(keyPath)") }

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

/// A JWT for the App Store Connect API. Valid for 20 minutes, the most Apple allows.
func token() -> String {
    let now = Int(Date().timeIntervalSince1970)
    let header = try! JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyID, "typ": "JWT"])
    let payload = try! JSONSerialization.data(withJSONObject: [
        "iss": issuerID, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1",
    ])
    let signingInput = base64URL(header) + "." + base64URL(payload)
    let signature = try! key.signature(for: Data(signingInput.utf8))
    return signingInput + "." + base64URL(signature.rawRepresentation)
}

// MARK: - Requests

@discardableResult
func request(_ method: String, _ path: String, query: [String: String] = [:], body: [String: Any]? = nil) -> [String: Any] {
    var components = URLComponents(url: api.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    if !query.isEmpty { components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
    var req = URLRequest(url: components.url!)
    req.httpMethod = method
    req.setValue("Bearer \(token())", forHTTPHeaderField: "Authorization")
    if let body {
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try! JSONSerialization.data(withJSONObject: body)
    }
    var result: (Data?, URLResponse?, Error?)
    let done = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { result = ($0, $1, $2); done.signal() }.resume()
    done.wait()
    if let error = result.2 { fail("\(method) \(path): \(error.localizedDescription)") }
    let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
    let data = result.0 ?? Data()
    guard (200..<300).contains(status) else {
        fail("\(method) \(path) returned \(status): \(String(decoding: data, as: UTF8.self))")
    }
    guard !data.isEmpty else { return [:] }
    return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
}

func items(_ response: [String: Any]) -> [[String: Any]] { response["data"] as? [[String: Any]] ?? [] }
func attributes(_ item: [String: Any]) -> [String: Any] { item["attributes"] as? [String: Any] ?? [:] }

// MARK: - Find the app and the build

guard let app = items(request("GET", "apps", query: ["filter[bundleId]": bundleID, "fields[apps]": "primaryLocale"])).first,
      let appID = app["id"] as? String
else { fail("no app with bundle ID \(bundleID) in App Store Connect") }
let locale = attributes(app)["primaryLocale"] as? String ?? "en-US"

log("Waiting for build \(marketing) (\(build)) to finish processing (up to \(Int(waitMinutes)) minutes)")
let deadline = Date().addingTimeInterval(waitMinutes * 60)
var buildID: String?
while buildID == nil {
    let found = items(request("GET", "builds", query: [
        "filter[app]": appID,
        "filter[version]": build,
        "filter[preReleaseVersion.version]": marketing,
        "fields[builds]": "processingState",
        "limit": "1",
    ])).first
    let state = found.flatMap { attributes($0)["processingState"] as? String }
    switch state {
    case "VALID":
        buildID = found?["id"] as? String
    case "FAILED", "INVALID":
        fail("App Store Connect marked build \(build) as \(state!)")
    default:
        guard Date() < deadline else { fail("build \(build) wasn't ready after \(Int(waitMinutes)) minutes (state: \(state ?? "not found yet"))") }
        Thread.sleep(forTimeInterval: 30)
    }
}

// MARK: - Write the notes

let existing = items(request("GET", "builds/\(buildID!)/betaBuildLocalizations", query: ["fields[betaBuildLocalizations]": "locale"]))
if let current = existing.first(where: { attributes($0)["locale"] as? String == locale }), let id = current["id"] as? String {
    request("PATCH", "betaBuildLocalizations/\(id)", body: [
        "data": ["type": "betaBuildLocalizations", "id": id, "attributes": ["whatsNew": notes]],
    ])
} else {
    request("POST", "betaBuildLocalizations", body: [
        "data": [
            "type": "betaBuildLocalizations",
            "attributes": ["whatsNew": notes, "locale": locale],
            "relationships": ["build": ["data": ["type": "builds", "id": buildID!]]],
        ],
    ])
}
log("Set What to Test (\(locale)) on build \(marketing) (\(build))")
