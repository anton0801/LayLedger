//
//  UIKitBridges.swift
//  LayLedger
//
//  UIKit interop: photo picking (PHPicker), share sheet, image downscaling.
//

import SwiftUI
import UIKit
import PhotosUI

/// Downscale + compress a picked image so persisted Data stays small.
func resizedImageData(_ image: UIImage, maxDimension: CGFloat = 1100, quality: CGFloat = 0.7) -> Data? {
    let size = image.size
    guard size.width > 0, size.height > 0 else { return image.jpegData(compressionQuality: quality) }
    let scale = min(1, maxDimension / max(size.width, size.height))
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    let resized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return resized.jpegData(compressionQuality: quality)
}

// MARK: - Photo picker (PHPicker)

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    var onPicked: ((Data) -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage,
                      let data = resizedImageData(image) else { return }
                DispatchQueue.main.async {
                    self.parent.imageData = data
                    self.parent.onPicked?(data)
                }
            }
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Image from Data helper

extension Image {
    init?(data: Data?) {
        guard let data = data, let ui = UIImage(data: data) else { return nil }
        self = Image(uiImage: ui)
    }
}
