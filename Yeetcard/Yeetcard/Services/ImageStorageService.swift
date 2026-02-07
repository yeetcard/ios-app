//
//  ImageStorageService.swift
//  Yeetcard
//

import UIKit

protocol ImageStorageServiceProtocol {
    func saveImage(_ image: UIImage, cardId: UUID) -> (imagePath: String, thumbnailPath: String)?
    func loadImage(named name: String) -> UIImage?
    func deleteImages(imagePath: String, thumbnailPath: String)
    func getFullPath(for imageName: String) -> URL
}

final class ImageStorageService: ImageStorageServiceProtocol {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default
    private let imageDirectoryName = "CardImages"
    private let thumbnailSize = CGSize(width: 300, height: 200)
    private let jpegQuality: CGFloat = 0.8

    private var imageDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(imageDirectoryName)
    }

    private init() {
        createImageDirectoryIfNeeded()
    }

    private func createImageDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: imageDirectory.path) {
            try? fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
    }

    func saveImage(_ image: UIImage, cardId: UUID) -> (imagePath: String, thumbnailPath: String)? {
        let imageName = "\(cardId.uuidString).jpg"
        let thumbnailName = "\(cardId.uuidString)_thumb.jpg"

        let imagePath = imageDirectory.appendingPathComponent(imageName)
        let thumbnailPath = imageDirectory.appendingPathComponent(thumbnailName)

        guard let imageData = image.jpegData(compressionQuality: jpegQuality) else {
            return nil
        }

        do {
            try imageData.write(to: imagePath)

            if let thumbnail = generateThumbnail(from: image) {
                if let thumbnailData = thumbnail.jpegData(compressionQuality: jpegQuality) {
                    try thumbnailData.write(to: thumbnailPath)
                }
            }

            return (imageName, thumbnailName)
        } catch {
            return nil
        }
    }

    func loadImage(named name: String) -> UIImage? {
        let imagePath = imageDirectory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: imagePath.path) else { return nil }
        return UIImage(contentsOfFile: imagePath.path)
    }

    func deleteImages(imagePath: String, thumbnailPath: String) {
        let imageURL = imageDirectory.appendingPathComponent(imagePath)
        let thumbnailURL = imageDirectory.appendingPathComponent(thumbnailPath)

        try? fileManager.removeItem(at: imageURL)
        try? fileManager.removeItem(at: thumbnailURL)
    }

    private func generateThumbnail(from image: UIImage) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        var targetSize = thumbnailSize

        if aspectRatio > thumbnailSize.width / thumbnailSize.height {
            targetSize.height = thumbnailSize.width / aspectRatio
        } else {
            targetSize.width = thumbnailSize.height * aspectRatio
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func getFullPath(for imageName: String) -> URL {
        imageDirectory.appendingPathComponent(imageName)
    }
}
