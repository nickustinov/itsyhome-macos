//
//  SpeechTranscriber.swift
//  macOSBridge
//
//  Whisper-based speech recognition for the /voice/transcribe webhook
//  endpoint. WhisperKit downloads the tiny.en CoreML model on first use
//  (~40 MB) into the user's Application Support directory and runs
//  inference on-device. No system Dictation toggle required and the
//  audio never leaves the Mac.
//

import Foundation
import WhisperKit

enum SpeechTranscribeError: Error {
    case notReady
    case bufferConversionFailed
    case modelLoadFailed(String)
    case underlying(Error)
}

enum SpeechTranscriber {

    // The pipeline is lazily loaded the first time someone calls
    // `prepare()` or `transcribe(...)`. We hold the Task so concurrent
    // requests share the same load (and the same download).
    private static var pipelineTask: Task<WhisperKit, Error>?
    private static let modelVariant = "openai_whisper-tiny.en"

    /// True iff the user has flipped the voice toggle on. The first
    /// `transcribe(...)` call will lazy-load the pipeline (or trigger
    /// the download) — keeping the gating simple here so the glasses
    /// app can advertise the row immediately after the user opts in,
    /// even before the model finishes loading.
    static func isAvailable() -> Bool {
        UserDefaults.standard.bool(forKey: WebhooksSection.voiceEnabledKey)
    }

    /// Kick off the model download / load. Safe to call multiple times —
    /// re-entrant callers wait on the existing task instead of starting
    /// a parallel download. Returns the loaded WhisperKit pipeline.
    @discardableResult
    static func prepare() -> Task<WhisperKit, Error> {
        if let task = pipelineTask { return task }
        let task = Task<WhisperKit, Error> {
            do {
                // tiny.en is ~40 MB and decoding latency on M-series is
                // < 200 ms for a 5 s utterance. English-only — we're
                // explicitly scoped to that for now.
                let config = WhisperKitConfig(
                    model: modelVariant,
                    verbose: false,
                    logLevel: .error,
                    prewarm: true,
                    load: true
                )
                return try await WhisperKit(config)
            } catch {
                // Drop the cached task on failure so a retry kicks a new
                // download. Otherwise we'd be stuck returning the same
                // error forever.
                pipelineTask = nil
                throw SpeechTranscribeError.modelLoadFailed(error.localizedDescription)
            }
        }
        pipelineTask = task
        return task
    }

    /// Drop the cached pipeline so the next call re-loads from scratch.
    /// Used when the user toggles the feature off.
    static func unload() {
        pipelineTask = nil
    }

    /// Run speech recognition over a raw PCM payload. The buffer must be
    /// little-endian signed 16-bit, 16 kHz, mono — matching what the
    /// glasses SDK emits via the audio event. The returned tuple is the
    /// concatenated transcript plus an aggregated confidence value.
    ///
    /// `prompt` is a free-form catalog snippet (device / room / scene
    /// names, comma-separated) that biases the decoder toward those
    /// tokens. Truncate to ~200 chars on the caller side — Whisper's
    /// prefill context is limited to ~244 tokens.
    static func transcribe(pcm: Data, prompt: String? = nil, sampleRate _: Double = 16_000) async throws -> (text: String, confidence: Float) {
        let kit: WhisperKit
        do {
            kit = try await prepare().value
        } catch {
            throw error
        }
        guard pcm.count >= 2 else { throw SpeechTranscribeError.bufferConversionFailed }
        let samples = pcmInt16LEToFloat32(pcm)
        guard !samples.isEmpty else { throw SpeechTranscribeError.bufferConversionFailed }
        // Tokenise the catalog snippet into prompt tokens. Whisper biases
        // toward these as if they were a "previous context", so names
        // like "Ecobee" / "Aqara" / room names that aren't in the
        // language model end up far more reliably transcribed.
        var promptTokens: [Int]? = nil
        if let prompt = prompt, !prompt.isEmpty, let tokenizer = kit.tokenizer {
            promptTokens = tokenizer.encode(text: " " + prompt)
        }
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: "en",
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            promptTokens: promptTokens
        )
        do {
            let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
            // Each TranscriptionResult carries a top-level `text` (the
            // joined segment text) plus per-segment `avgLogprob`. We
            // concatenate texts across results and average the segment
            // log-probabilities — `exp(avgLogprob)` maps the [-∞, 0] log
            // range to a [0, 1] confidence heuristic.
            let text = results
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let allSegments = results.flatMap { $0.segments }
            let avgLogprob: Float = allSegments.isEmpty
                ? 0
                : allSegments.map { $0.avgLogprob }.reduce(0, +) / Float(allSegments.count)
            let confidence: Float = exp(avgLogprob)
            return (text, confidence.isFinite ? confidence : 0)
        } catch {
            throw SpeechTranscribeError.underlying(error)
        }
    }

    /// Convert a little-endian signed 16-bit PCM buffer to a Float32
    /// array in [-1, 1]. The 16 kHz mono assumption matches what the
    /// glasses send.
    private static func pcmInt16LEToFloat32(_ pcm: Data) -> [Float] {
        let sampleCount = pcm.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return [] }
        var out = [Float](repeating: 0, count: sampleCount)
        pcm.withUnsafeBytes { rawBuf in
            guard let p = rawBuf.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in 0..<sampleCount {
                let s = p[i].littleEndian
                out[i] = Float(s) / 32768.0
            }
        }
        return out
    }
}
