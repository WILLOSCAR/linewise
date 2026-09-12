import AVFoundation
import Foundation
import Speech

/// 语音转文字（本机识别优先）。失败时给出可读错误，界面回退到打字。
@Observable
final class SpeechDictation {
    private(set) var isRecording = false
    private(set) var transcript = ""
    private(set) var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    var isAvailable: Bool {
        SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))?.isAvailable ?? false
    }

    func toggle() {
        if isRecording { stop() } else { Task { await start() } }
    }

    func start() async {
        errorMessage = nil
        transcript = ""
        let speechStatus = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            errorMessage = "没有语音识别权限，可以直接打字。"
            return
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            errorMessage = "没有麦克风权限，可以直接打字。"
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.isAvailable else {
            errorMessage = "当前不能语音识别，可以直接打字。"
            return
        }
        self.recognizer = recognizer

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "麦克风不可用，可以直接打字。"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            errorMessage = "录音启动失败，可以直接打字。"
            return
        }
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let text { self.transcript = text }
                if final || failed { self.finishEngine() }
            }
        }
    }

    func stop() {
        request?.endAudio()
        finishEngine()
    }

    private func finishEngine() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        task?.finish()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
