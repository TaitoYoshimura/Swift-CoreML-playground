//
//  ContentView.swift
//  coreML-playground
//
//  Created by yoshimura on 2025/10/29.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraView(viewModel: viewModel)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                Text("推論結果")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let result = viewModel.latestResult {
                    Text(result.identifier)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)

                    Text(result.confidenceDescription)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text(viewModel.statusMessage)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
        .overlay {
            if !viewModel.isAuthorized {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)

                    Text(viewModel.statusMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }
                .padding()
                .frame(maxWidth: 320)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding()
            }
        }
        .onAppear {
            viewModel.requestAccessAndConfigure()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

#Preview {
    ContentView()
}
