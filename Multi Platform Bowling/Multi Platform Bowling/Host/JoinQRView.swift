#if os(macOS) || os(tvOS)
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct JoinQRView: View {
    let payload: String?
    var dimension: CGFloat = 240

    var body: some View {
        VStack(spacing: 10) {
            qrImage
                .frame(width: dimension, height: dimension)
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("Scan with iPhone")
                .font(.headline)
            Text("Joins faster and locks throw aim to this screen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var qrImage: some View {
        if let payload, let image = JoinQRRenderer.image(from: payload, dimension: dimension) {
            #if os(macOS)
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
            #else
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
            #endif
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }
}

enum JoinQRRenderer {
    #if os(macOS)
    static func image(from payload: String, dimension: CGFloat) -> NSImage? {
        guard let cgImage = makeCGImage(from: payload, dimension: dimension) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: dimension, height: dimension))
    }
    #else
    static func image(from payload: String, dimension: CGFloat) -> UIImage? {
        guard let cgImage = makeCGImage(from: payload, dimension: dimension) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    #endif

    private static func makeCGImage(from payload: String, dimension: CGFloat) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "Q"
        guard let output = filter.outputImage else { return nil }
        let scale = max(dimension / output.extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
#endif
