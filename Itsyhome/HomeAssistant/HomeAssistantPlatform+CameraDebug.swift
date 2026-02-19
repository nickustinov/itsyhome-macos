//
//  HomeAssistantPlatform+CameraDebug.swift
//  Itsyhome
//
//  Camera debug diagnostics
//

import Foundation

extension HomeAssistantPlatform {

    // MARK: - Camera debug

    func getCameraDebugJSON(entityId: String? = nil) async -> String {
        var allCameras = mapper.getAllCameraEntities()

        if let entityId = entityId {
            allCameras = allCameras.filter { $0.entityId == entityId }
        }

        guard !allCameras.isEmpty else {
            if let entityId = entityId {
                return "{\"error\":\"Camera not found: \(entityId)\"}"
            }
            return "{\"cameras\":[],\"summary\":{\"total\":0,\"shown_in_app\":0,\"filtered_out\":0}}"
        }

        let results = await withTaskGroup(of: [String: Any].self) { group in
            for camera in allCameras {
                group.addTask { [weak self] in
                    await self?.probeCameraEntity(camera) ?? [:]
                }
            }

            var collected: [[String: Any]] = []
            for await result in group {
                if !result.isEmpty {
                    collected.append(result)
                }
            }
            return collected.sorted { ($0["entity_id"] as? String ?? "") < ($1["entity_id"] as? String ?? "") }
        }

        let shownCount = results.filter { $0["shown_in_app"] as? Bool == true }.count
        let filteredCount = results.count - shownCount

        let response: [String: Any] = [
            "cameras": results,
            "summary": [
                "total": results.count,
                "shown_in_app": shownCount,
                "filtered_out": filteredCount
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{\"error\":\"Failed to serialize debug data\"}"
    }

    private func probeCameraEntity(_ camera: HAEntityState) async -> [String: Any] {
        let features = camera.supportedFeatures
        let isAvailable = camera.state != "unavailable"

        var info: [String: Any] = [
            "entity_id": camera.entityId,
            "name": camera.friendlyName,
            "state": camera.state,
            "supported_features": features,
            "shown_in_app": isAvailable,
            "all_attributes": sanitizeAttributes(camera.attributes)
        ]

        if !isAvailable {
            info["filter_reason"] = "Camera unavailable"
        }

        var tests: [String: Any] = [:]
        tests["snapshot"] = await probeSnapshot(entityId: camera.entityId)
        tests["hls"] = await probeHLS(entityId: camera.entityId)
        tests["webrtc"] = await probeWebRTC(entityId: camera.entityId)
        info["tests"] = tests

        return info
    }

    private func probeSnapshot(entityId: String) async -> [String: Any] {
        guard let snapshotURL = client?.getCameraSnapshotURL(entityId: entityId),
              let token = HAAuthManager.shared.accessToken else {
            return ["status": "error", "error": "Not connected"]
        }

        var request = URLRequest(url: snapshotURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            let httpResponse = response as? HTTPURLResponse

            if let status = httpResponse?.statusCode, 200..<300 ~= status {
                return [
                    "status": "ok",
                    "http_status": status,
                    "content_type": httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? "unknown",
                    "size_bytes": data.count,
                    "elapsed_ms": elapsed
                ]
            } else {
                return [
                    "status": "error",
                    "http_status": httpResponse?.statusCode ?? 0,
                    "error": "HTTP \(httpResponse?.statusCode ?? 0)",
                    "elapsed_ms": elapsed
                ]
            }
        } catch {
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            return ["status": "error", "error": error.localizedDescription, "elapsed_ms": elapsed]
        }
    }

    private func probeHLS(entityId: String) async -> [String: Any] {
        guard let client = client else {
            return ["status": "error", "error": "Not connected"]
        }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let url = try await client.getCameraStreamURL(entityId: entityId)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            return ["status": "ok", "url": url.absoluteString, "elapsed_ms": elapsed]
        } catch {
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            return ["status": "error", "error": error.localizedDescription, "elapsed_ms": elapsed]
        }
    }

    private func probeWebRTC(entityId: String) async -> [String: Any] {
        guard let client = client else {
            return ["status": "error", "error": "Not connected"]
        }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            // sendAndWait succeeds = HA accepted the WebRTC command (camera supports it)
            // sendAndWait throws = HA rejected (camera doesn't support WebRTC)
            let result = try await client.probeWebRTCSupport(entityId: entityId)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            var response: [String: Any] = [
                "status": "ok",
                "elapsed_ms": elapsed
            ]
            if let answer = result["answer"] as? String, !answer.isEmpty {
                response["has_answer"] = true
            }
            return response
        } catch {
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            return ["status": "error", "error": error.localizedDescription, "elapsed_ms": elapsed]
        }
    }

    /// Sanitize attributes for JSON serialization (convert non-serializable values to strings)
    /// Redacts tokens so users feel comfortable sharing debug output
    private func sanitizeAttributes(_ attrs: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in attrs {
            if key == "access_token" || key == "token" {
                if let token = value as? String, token.count > 8 {
                    result[key] = String(token.prefix(4)) + "…" + String(token.suffix(4))
                } else {
                    result[key] = "***"
                }
            } else if let str = value as? String, str.contains("token=") {
                result[key] = str.replacingOccurrences(
                    of: "(token=)([a-fA-F0-9]{8})[a-fA-F0-9]+([a-fA-F0-9]{4})",
                    with: "$1$2…$3",
                    options: .regularExpression
                )
            } else if JSONSerialization.isValidJSONObject([key: value]) {
                result[key] = value
            } else {
                result[key] = String(describing: value)
            }
        }
        return result
    }
}
