//
//  LoginView.swift
//  Project MultiNav App
//
//  Created by WAIVE lab on 6/19/26.
//

import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var participantID: Int

    var body: some View {
        VStack(spacing: 20) {
            TextField("participantID", value: $participantID, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 140, height: 38)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )

            Button("Log in") {
                let _ = print("Logged in with ID value of \(participantID)")
                isLoggedIn = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
