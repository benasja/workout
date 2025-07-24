//
//  ExerciseDetailView.swift
//  work
//
//  Created by Kiro on 7/24/25.
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition
    @EnvironmentObject private var dataManager: DataManager
    @State private var sets: [WorkoutSet] = []
    @State private var personalRecords: (bestSet: WorkoutSet?, maxVolume: Double, estimatedOneRepMax: Double) = (nil, 0.0, 0.0)
    @State private var chartData: [ChartDataPoint] = []
    @State private var selectedDataPoint: ChartDataPoint?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Personal Records Card
                PersonalRecordsCard(personalRecords: personalRecords)
                
                // Performance Graph Card
                PerformanceGraphCard(
                    chartData: chartData,
                    selectedDataPoint: $selectedDataPoint,
                    exerciseName: exercise.name
                )
                
                // History Section
                HistorySection(sets: sets)
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        sets = dataManager.getSetsForExercise(exercise)
        personalRecords = dataManager.getPersonalRecords(for: exercise)
        generateChartData()
    }
    
    private func generateChartData() {
        // Group sets by workout session date and find the highest e1RM for each session
        let groupedSets = Dictionary(grouping: sets) { set in
            Calendar.current.startOfDay(for: set.date)
        }
        
        chartData = groupedSets.compactMap { (date, sets) in
            guard let maxE1RM = sets.map(\.e1RM).max() else { return nil }
            return ChartDataPoint(date: date, value: maxE1RM)
        }.sorted { $0.date < $1.date }
    }
}

struct PersonalRecordsCard: View {
    let personalRecords: (bestSet: WorkoutSet?, maxVolume: Double, estimatedOneRepMax: Double)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Records")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let bestSet = personalRecords.bestSet {
                        Text("\(bestSet.weight.formatted(.number.precision(.fractionLength(1)))) kg × \(bestSet.reps) reps")
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Text("No data")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Est. 1RM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(personalRecords.estimatedOneRepMax.formatted(.number.precision(.fractionLength(1)))) kg")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(personalRecords.maxVolume.formatted(.number.precision(.fractionLength(0)))) kg")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PerformanceGraphCard: View {
    let chartData: [ChartDataPoint]
    @Binding var selectedDataPoint: ChartDataPoint?
    let exerciseName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Graph")
                .font(.title2)
                .fontWeight(.bold)
            
            if chartData.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No workout data yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Start logging sets to see your progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                Chart(chartData, id: \.date) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("e1RM", dataPoint.value)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, chartData.count / 5))) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HistorySection: View {
    let sets: [WorkoutSet]
    
    private var groupedSets: [(Date, [WorkoutSet])] {
        let grouped = Dictionary(grouping: sets) { set in
            Calendar.current.startOfDay(for: set.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("History")
                .font(.title2)
                .fontWeight(.bold)
            
            if sets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No workout history")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Start a workout to begin tracking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(groupedSets, id: \.0) { date, sets in
                        WorkoutHistoryCard(date: date, sets: sets)
                    }
                }
            }
        }
    }
}

struct WorkoutHistoryCard: View {
    let date: Date
    let sets: [WorkoutSet]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date, format: .dateTime.weekday(.wide).month().day())
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(sets.count) sets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                Text("Set")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("Weight")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("Reps")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("e1RM")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                    Text("\(index + 1)")
                        .font(.subheadline)
                    
                    Text("\(set.weight.formatted(.number.precision(.fractionLength(1))))")
                        .font(.subheadline)
                    
                    Text("\(set.reps)")
                        .font(.subheadline)
                    
                    Text("\(set.e1RM.formatted(.number.precision(.fractionLength(1))))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ChartDataPoint {
    let date: Date
    let value: Double
}

#Preview {
    NavigationView {
        ExerciseDetailView(exercise: ExerciseDefinition(
            name: "Barbell Squat",
            instructions: "Squat down and up",
            primaryMuscleGroup: "Legs",
            equipment: "Barbell"
        ))
    }
    .environmentObject(DataManager(modelContext: ModelContext(try! ModelContainer(for: ExerciseDefinition.self, WorkoutSet.self))))
}