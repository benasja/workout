//
//  JournalView.swift
//  work
//
//  Created by Kiro on 12/19/24.
//

import SwiftUI
import SwiftData
import Foundation
import UIKit

struct JournalView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var selectedDate = Date()
    @State private var selectedTags: Set<String> = []
    @State private var notes: String = ""
    @State private var isLoading = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private var availableTags: [JournalTag] = JournalTag.allCases
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 28) {
                    // Date Picker at the top
                    DateSliderView(selectedDate: $selectedDate)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Tags Selection Section
                    ModernCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                Text("How was your day?")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            Text("Select what happened today:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 14) {
                                ForEach(availableTags, id: \.self) { tag in
                                    ModernTagToggleView(
                                        tag: tag,
                                        isSelected: selectedTags.contains(tag.rawValue)
                                    ) {
                                        toggleTagAndSave(tag.rawValue)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)

                    // Notes Section
                    // REMOVED: Additional Notes card
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .background(AppColors.background)
            .refreshable {
                loadEntryForDate()
            }
            .onAppear {
                loadEntryForDate()
            }
            .onChange(of: selectedDate) {
                loadEntryForDate()
            }
            .onChange(of: dataManager.currentJournalEntry) {
                updateUI(from: dataManager.currentJournalEntry)
            }
            .alert("Save Failed", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text("Unable to save your changes: \(errorMessage)")
            }
        }
    }
    
    private func loadEntryForDate() {
        dataManager.fetchJournalEntry(for: selectedDate)
    }
    
    private func updateUI(from entry: DailyJournal?) {
        if let entry = entry {
            selectedTags = Set(entry.selectedTags)
            notes = entry.notes ?? ""
        } else {
            selectedTags = []
            notes = ""
        }
    }
    
    private func toggleTagAndSave(_ tagRawValue: String) {
        if selectedTags.contains(tagRawValue) {
            selectedTags.remove(tagRawValue)
        } else {
            selectedTags.insert(tagRawValue)
        }
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        autoSave()
    }
    
    private func autoSave() {
        do {
            try dataManager.saveJournalEntry(for: selectedDate, tags: selectedTags, notes: notes)
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

// MARK: - Tag Toggle Views

struct ModernTagToggleView: View {
    let tag: JournalTag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tag.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : tag.color)
                
                Text(tag.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(minHeight: 70)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? tag.color : Color(.systemGray6))
                    .shadow(color: isSelected ? tag.color.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tag.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TagToggleView: View {
    let tag: JournalTag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tag.icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : tag.color)
                
                Text(tag.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? tag.color : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tag.color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct JournalView_Preview_Container: View {
    let result: Result<ModelContainer, Error>

    init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: DailyJournal.self, configurations: config)
            self.result = .success(container)
        } catch {
            self.result = .failure(error)
        }
    }

    var body: some View {
        switch result {
        case .success(let container):
            let dataManager = DataManager(modelContext: container.mainContext)
            JournalView()
                .modelContainer(container)
                .environmentObject(dataManager)
        case .failure(let error):
            Text("Failed to create container: \(error.localizedDescription)")
        }
    }
}

#Preview {
    JournalView_Preview_Container()
}