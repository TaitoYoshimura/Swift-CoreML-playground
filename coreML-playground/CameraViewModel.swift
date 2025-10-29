//
//  CameraViewModel.swift
//  coreML-playground
//
//  Created by Codex on 2025/02/09.
//

import AVFoundation
import CoreML
import Vision

final class CameraViewModel: NSObject, ObservableObject {
    struct ClassificationResult {
        let identifier: String
        let confidence: Double

        var confidenceDescription: String {
            String(format: "%.0f%%", confidence * 100)
        }
    }

    @Published var isAuthorized = false
    @Published var statusMessage = "カメラを準備中..."
    @Published var latestResult: ClassificationResult?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let inferenceQueue = DispatchQueue(label: "camera.inference.queue")
    private var isSessionConfigured = false
    private var lastClassificationDate = Date.distantPast
    private let classificationInterval: TimeInterval = 0.5

    private lazy var classifyRequest: VNClassifyImageRequest = {
        let request = VNClassifyImageRequest { [weak self] request, error in
            guard let self else { return }
            if let observations = request.results as? [VNClassificationObservation],
               let best = observations.first {
                DispatchQueue.main.async {
                    self.latestResult = ClassificationResult(identifier: best.identifier, confidence: Double(best.confidence))
                    self.statusMessage = "推論結果"
                }
            } else if let error {
                DispatchQueue.main.async {
                    self.latestResult = nil
                    self.statusMessage = "推論エラー: \(error.localizedDescription)"
                }
            }
        }
        return request
    }()

    func requestAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            statusMessage = "推論準備中..."
            configureSessionIfNeeded()
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    self.statusMessage = granted ? "推論準備中..." : "カメラが許可されていません"
                }
                if granted {
                    self.configureSessionIfNeeded()
                    self.startSession()
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.statusMessage = "設定アプリからカメラへのアクセスを許可してください"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.statusMessage = "カメラの権限状態を取得できません"
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.isAuthorized else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isSessionConfigured else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async {
                    self.statusMessage = "背面カメラを取得できません"
                }
                self.session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    DispatchQueue.main.async {
                        self.statusMessage = "カメラ入力を追加できません"
                    }
                    self.session.commitConfiguration()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "カメラ入力の設定に失敗しました: \(error.localizedDescription)"
                }
                self.session.commitConfiguration()
                return
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: self.inferenceQueue)

            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = "ビデオ出力の追加に失敗しました"
                }
                self.session.commitConfiguration()
                return
            }

            if let connection = videoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            self.session.commitConfiguration()
            self.isSessionConfigured = true
        }
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastClassificationDate) > classificationInterval else {
            return
        }
        lastClassificationDate = now

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([classifyRequest])
        } catch {
            DispatchQueue.main.async {
                self.latestResult = nil
                self.statusMessage = "推論の実行に失敗しました: \(error.localizedDescription)"
            }
        }
    }
}
