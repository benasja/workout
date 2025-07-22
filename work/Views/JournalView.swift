//
//  JournalView.swift
//  work
//
//  Created by Kiro on 12/19/24.
//

import SwiftUI
import SwiftData
import Foundation

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyJournal.date, order: .reverse) private var journalEntries: [DailyJournal]
    
    @State private var selectedDate = Date()
    @State private var selectedTags: Set<JournalTag> = []
    @State private var notes: String = ""
    @State private var showingSaveConfirmation = false
    
    private var currentEntry: DailyJournal? {
        let calendar = Calendar.current
        return journalEntries.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    private let availableTags: [JournalTag] = [
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
                                        toggleTag(tag)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)

                    // Notes Section
                    ModernCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("Additional Notes")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            TextField("How are you feeling? Any thoughts or observations...", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                                .font(.body)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)

                    // Save Button
                    Button(action: saveEntry) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                            Text("Save Entry")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .shadow(color: .blue.opacity(0.18), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                    // Current Entry Summary (if exists)
                    if let entry = currentEntry, (!entry.tags.isEmpty || !(entry.notes?.isEmpty ?? true)) {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.purple)
                                        .font(.title2)
                                    Text("Entry for \(selectedDate, style: .date)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                if !entry.tags.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Tags:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                            ForEach(entry.tags, id: \.self) { tagName in
                                                if let tag = availableTags.first(where: { $0.displayName == tagName }) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: tag.icon)
                                                            .font(.caption)
                                                        Text(tag.displayName)
                                                            .font(.caption)
                                                            .fontWeight(.medium)
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(tag.color.opacity(0.18))
                                                    .foregroundColor(tag.color)
                                                    .cornerRadius(12)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(tag.color.opacity(0.3), lineWidth: 1)
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                                if let entryNotes = entry.notes, !entryNotes.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Notes:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        Text(entryNotes)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .padding(12)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
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
            .alert("Entry Saved! ✅", isPresented: $showingSaveConfirmation) {
                Button("OK") { }
            } message: {
                Text("Your journal entry has been saved successfully.")
            }
        }
    }
    
    private func toggleTag(_ tag: JournalTag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func loadEntryForDate() {
        selectedTags.removeAll()
        notes = ""
        
        if let entry = currentEntry {
            // Load existing entry data
            selectedTags = Set(entry.tags.compactMap { tagString in
                availableTags.first { $0.displayName == tagString }
            })
            notes = entry.notes ?? ""
        }
    }
    
    private func saveEntry() {
        let entry: DailyJournal
        
        if let existingEntry = currentEntry {
            entry = existingEntry
        } else {
            entry = DailyJournal(date: selectedDate)
            modelContext.insert(entry)
        }
        
        // Update entry with selected data
        updateEntryFromTags(entry)
        entry.notes = notes.isEmpty ? nil : notes
        
        do {
            try modelContext.save()
            showingSaveConfirmation = true
            print("✅ Journal entry saved for \(selectedDate)")
        } catch {
            print("❌ Failed to save journal entry: \(error)")
        }
    }
    
    private func updateEntryFromTags(_ entry: DailyJournal) {
        // Reset all boolean flags
        entry.consumedAlcohol = false
        entry.caffeineAfter2PM = false
        entry.ateLate = false
        entry.highStressDay = false
        entry.alcohol = false
        entry.illness = false
        // Set flags based on selected tags
        for tag in selectedTags {
            switch tag {
            case .alcohol:
                entry.consumedAlcohol = true
                entry.alcohol = true
            case .caffeine, .coffee:
                entry.caffeineAfter2PM = true
            case .lateEating:
                entry.ateLate = true
            case .stress:
                entry.highStressDay = true
            case .illness:
                entry.illness = true
            case .poorSleep:
                entry.wellness = .poor
            case .goodSleep:
                entry.wellness = .excellent
            default:
                break
            }
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

#Preview {
    JournalView()
        .modelContainer(for: [DailyJournal.self])
}