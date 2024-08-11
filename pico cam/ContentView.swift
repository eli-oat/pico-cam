//
//  ContentView.swift
//  pico cam
//
//  Created by eli_oat on 8/10/24.
//

import SwiftUI

struct ContentView: View {
    @State private var showInfo = false
    @State private var processedImage: UIImage?
    @State private var isSaving = false
    @State private var saveSuccess = false

    var body: some View {
        ZStack {
            // FIXME: this means that obscured behind the dithered preview there is a teeny tiny preview that shows unprocessed cameraa output -- is this really necessary?
            CameraView(processedImage: $processedImage)
                .scaleEffect(CGSize(width: 0.25, height: 0.25)) // make it smaller than the actual image preview so that it is hidden.
                .edgesIgnoringSafeArea(.all)
            
            // Preview dithered image
            if let processedImage = processedImage {
                Image(uiImage: processedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .edgesIgnoringSafeArea(.all)
            } else {
                // Placeholder while processing
                Color.black.edgesIgnoringSafeArea(.all)
                Text("No image available.")
                    .foregroundColor(.white)
            }

            VStack {
                HStack {
                    Button(action: {
                        showInfo.toggle()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 40, height: 40)
                            .padding()
                            .overlay(
                                Image(systemName: "info.circle")
                                    .font(.largeTitle)
                                    .padding()
                                    .foregroundColor(.black)  // Make sure that the button is visible
                            )
                    }
                    Spacer()
                }
                Spacer()
                Button(action: {
                    if let image = processedImage {
                        saveImageToCameraRoll(image)
                    }
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "camera.aperture")
                                .font(.largeTitle)
                                .foregroundColor(.black)
                        )
                }
                .padding(.bottom, 50)
            }
            .zIndex(2)  // FIXME: Where is the info button going!?

            if isSaving {
                VStack {
                    Text("Saving...")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
                .zIndex(2)
            }

            if saveSuccess {
                VStack {
                    Text("Saved!")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        saveSuccess = false
                    }
                }
                .zIndex(2)
            }
        }
        .sheet(isPresented: $showInfo) {
            InfoView()
        }
    }

    func saveImageToCameraRoll(_ image: UIImage) {
        isSaving = true
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        isSaving = false
        saveSuccess = true
    }
}
