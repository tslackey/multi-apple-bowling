#if os(iOS)
import ARKit
import RealityKit
import SwiftUI

struct QRScannerView: View {
    var session: LaneAnchorSession
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            ARSessionPreview(session: session.session)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(session.statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()

                Spacer()

                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.85), lineWidth: 3)
                    .frame(width: 240, height: 240)
                    .padding(.bottom, 24)

                Spacer()

                if let errorText = session.errorText {
                    Text(errorText)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Cancel", action: onCancel)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            session.beginScanning()
        }
    }
}

struct ARSessionPreview: UIViewRepresentable {
    var session: ARSession

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session = session
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
#endif
