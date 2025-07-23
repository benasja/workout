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
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var selectedTags: Set<JournalTag> = []
    @State private var notes: String = ""
    @State private var currentEntry: DailyJournal? = nil
    @State private var isLoading = false
    
    private var availableTags: [JournalTag] = [
        .coffee, .alcohol, .caffeine, .lateEating, .stress, .exercise, .meditation,
        .goodSleep, .poorSleep, .illness, .travel, .work, .social, .supplements,
        .hydration, .mood, .energy, .focus, .recovery
    ]
    
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
                                        isSelected: selectedTags.contains(tag)
                                    ) {
                                        toggleTagAndSave(tag)
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
            .onChange(of: selectedDate) { _, _ in
                loadEntryForDate()
            }
        }
    }
    
    private func loadEntryForDate() {
        isLoading = true
        if let entry = JournalManager.shared.fetchEntry(for: selectedDate, context: modelContext) {
            currentEntry = entry
            // Restore UI state from selectedTags
            selectedTags = Set(entry.selectedTags.compactMap { JournalTag(rawValue: $0) })
            notes = entry.notes ?? ""
        } else {
            currentEntry = nil
            selectedTags = []
            notes = ""
        }
        isLoading = false
    }
    
    private func toggleTagAndSave(_ tag: JournalTag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        autoSave()
    }
    
    private func autoSave() {
        JournalManager.shared.saveEntry(for: selectedDate, tags: selectedTags, notes: notes, context: modelContext)
        // No reload here; UI state is already up to date
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

#Preview {
    JournalView()
        .modelContainer(for: [DailyJournal.self])
}