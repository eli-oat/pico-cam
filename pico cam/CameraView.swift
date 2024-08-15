//
//  CameraView.swift
//  pico cam
//
//  Created by eli_oat on 8/10/24.
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct CameraView: UIViewControllerRepresentable {
    @Binding var processedImage: UIImage?

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            print("captureOutput called")
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                print("Image buffer captured.")
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)

                // Apply the dithering function to the CIImage
                if let processedImage = self.parent.applyDithering(to: ciImage) {
                    print("Dithered image successfully created.")
                    DispatchQueue.main.async {
                        self.parent.processedImage = processedImage
                    }
                } else {
                    print("Dithering failed, no processed image.")
                }
            } else {
                print("Failed to capture image buffer.")
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()

        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get the video device.")
            return controller
        }

        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice), captureSession.canAddInput(videoDeviceInput) else {
            print("Failed to create video device input.")
            return controller
        }
        captureSession.addInput(videoDeviceInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true  // Handle dropped frames
        videoOutput.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            print("Video output added to session.")
        } else {
            print("Failed to add video output to session.")
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill

        controller.view.layer.addSublayer(previewLayer)
        previewLayer.frame = controller.view.bounds

        // Capture session runs on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
            print("Capture session started.")
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func applyDithering(to ciImage: CIImage) -> UIImage? {
        print("Applying dithering...")
         
        // Gameboy camera is 160x144, but that makes math hard, so we go with dimensions closer to the phone
        // TODO: validate that this size works on things beside my  phone...maybe?
        let targetSize = CGSize(width: 160, height: 120)
       
        let resizedCIImage = ciImage
            .transformed(by: CGAffineTransform(scaleX: targetSize.width / ciImage.extent.width, y: targetSize.height / ciImage.extent.height))
            .transformed(by: CGAffineTransform(rotationAngle: -.pi / 2)) // Rotate the image 90 degrees

        let context = CIContext()
        guard let cgImage = context.createCGImage(resizedCIImage, from: resizedCIImage.extent) else {
            print("Failed to create CGImage from CIImage.")
            return nil
        }

        let width = Int(resizedCIImage.extent.width)
        let height = Int(resizedCIImage.extent.height)

        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            print("Failed to get image data from CGImage.")
            return nil
        }

        var pixels = [UInt8](repeating: 0, count: width * height)

        // Convert to grayscale
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = ptr[offset]
                let g = ptr[offset + 1]
                let b = ptr[offset + 2]
                let gray = 0.3 * Float(r) + 0.59 * Float(g) + 0.11 * Float(b)
                pixels[y * width + x] = UInt8(gray)
            }
        }

        // Apply dithering!
        for y in 0..<height {
            for x in 0..<width {
                let oldPixel = pixels[y * width + x]
                let newPixel: UInt8 = oldPixel < 128 ? 0 : 255
                let quantError = Int(oldPixel) - Int(newPixel)
                pixels[y * width + x] = newPixel

                if x + 1 < width {
                    pixels[y * width + x + 1] = UInt8(clamping: Int(pixels[y * width + x + 1]) + quantError * 7 / 16)
                }
                if y + 1 < height {
                    if x > 0 {
                        pixels[(y + 1) * width + x - 1] = UInt8(clamping: Int(pixels[(y + 1) * width + x - 1]) + quantError * 3 / 16)
                    }
                    pixels[(y + 1) * width + x] = UInt8(clamping: Int(pixels[(y + 1) * width + x]) + quantError * 5 / 16)
                    if x + 1 < width {
                        pixels[(y + 1) * width + x + 1] = UInt8(clamping: Int(pixels[(y + 1) * width + x + 1]) + quantError * 1 / 16)
                    }
                }
            }
        }

        // Make a new UIImage out of the dithered pixels
        let bitsPerComponent = 8
        let bitsPerPixel = 8
        let bytesPerRow = width
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let providerRef = CGDataProvider(data: NSData(bytes: pixels, length: pixels.count)) else {
            print("Failed to create data provider for dithered image.")
            return nil
        }

        guard let ditheredCGImage = CGImage(width: width,
                                            height: height,
                                            bitsPerComponent: bitsPerComponent,
                                            bitsPerPixel: bitsPerPixel,
                                            bytesPerRow: bytesPerRow,
                                            space: colorSpace,
                                            bitmapInfo: bitmapInfo,
                                            provider: providerRef,
                                            decode: nil,
                                            shouldInterpolate: false,
                                            intent: .defaultIntent) else {
            print("Failed to create dithered CGImage.")
            return nil
        }

        print("Dithering completed successfully.")

        return UIImage(cgImage: ditheredCGImage)
    }

}
