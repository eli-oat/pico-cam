//
//  CameraViewModel.swift
//  pico cam
//
//  Created by Eli Mellen on 8/10/24.
//

import SwiftUI
import AVFoundation

class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var processedImage: UIImage?
    @Published var isSaving = false
    @Published var saveSuccess = false
    @Published var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    private var captureSession: AVCaptureSession?

    func startCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession?.canAddInput(videoDeviceInput) == true else {
            print("Failed to create video device input.")
            return
        }
        captureSession?.addInput(videoDeviceInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

        if captureSession?.canAddOutput(videoOutput) == true {
            captureSession?.addOutput(videoOutput)
        }

        captureSession?.startRunning()
    }

    func stopCaptureSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }

    func saveImageToCameraRoll(_ image: UIImage) {
        isSaving = true
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        isSaving = false
        saveSuccess = true
    }

    func applyDithering(to ciImage: CIImage) -> UIImage? {
        // Implement the dithering algorithm here.
        // This is a placeholder for the actual dithering logic.

        // Example: Convert CIImage to UIImage (without actual dithering for brevity)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            if let processedImage = applyDithering(to: ciImage) {
                DispatchQueue.main.async {
                    self.processedImage = processedImage
                }
            }
        }
    }

    func getRotationAngle() -> Angle {
        switch deviceOrientation {
        case .landscapeLeft:
            return Angle(degrees: -90)
        case .landscapeRight:
            return Angle(degrees: 90)
        case .portraitUpsideDown:
            return Angle(degrees: 180)
        default:
            return Angle(degrees: 0)
        }
    }
}

