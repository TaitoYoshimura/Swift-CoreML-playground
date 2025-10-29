//
//  CameraView.swift
//  coreML-playground
//
//  Created by Codex on 2025/02/09.
//

import AVFoundation
import SwiftUI

struct CameraView: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = viewModel.session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== viewModel.session {
            uiView.videoPreviewLayer.session = viewModel.session
        }
    }
}

final class PreviewView: UIView {
    override static var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("レイヤーの取得に失敗しました")
        }
        return previewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = videoPreviewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}
