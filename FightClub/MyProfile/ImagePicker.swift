//
//  ImagePicker.swift
//  FightClub
//
//  Created by 김지훈 on 09/01/2025.
//

import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                print("이미지 선택 실패 또는 없음")
                return
            }

            provider.loadObject(ofClass: UIImage.self) { image, error in
                if let error = error {
                    print("이미지 로드 실패: \(error)")
                } else if let image = image as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image // `parent`를 통해 `selectedImage`에 접근
                        print("이미지 선택 성공: \(image)")
                    }
                }
            }
        }
    }
}
