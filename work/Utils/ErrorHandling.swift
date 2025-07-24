//
//  ErrorHandling.swift
//  work
//
//  Created by Kiro on 7/24/25.
//

import SwiftUI

// MARK: - Error Handling Utilities

struct ErrorAlert {
    static func show(error: Error, in view: some View) -> Alert {
        Alert(
            title: Text("Save Failed"),
            message: Text("Unable to save your changes: \(error.localizedDescription)"),
            dismissButton: .default(Text("OK"))
        )
    }
}

// MARK: - View Extension for Error Handling

extension View {
    func handleDataError(_ error: Error, showingAlert: Binding<Bool>) -> some View {
        self.alert("Save Failed", isPresented: showingAlert) {
            Button("OK") { }
        } message: {
            Text("Unable to save your changes: \(error.localizedDescription)")
        }
    }
}