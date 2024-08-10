//
//  InfoView.swift
//  pico cam
//
//  Created by eli_oat on 8/10/24.
//

import SwiftUI

struct InfoView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    // Dismiss the view by tapping "Done"
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done")
                        .font(.headline)
                        .padding()
                }
            }

            Text("Pico Cam")
                .font(.largeTitle)
                .padding()

            Text("Pico Cam is a camera for goblins. For folks who remember the days of yore and a certain eye-ball shaped contraption that you could stick into a handheld game console.")
                .padding()

            Spacer()
        }
        .padding()
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
    }
}
