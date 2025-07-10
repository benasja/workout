import SwiftUI

struct DetailedSleepScoreView: View {
    let sleepScore: SleepScoreResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Main Score Card
                    MainScoreCard(sleepScore: sleepScore)
                    
                    // Component Breakdown
                    ComponentBreakdownCard(sleepScore: sleepScore)
                    
                    // Key Findings
                    KeyFindingsCard(findings: sleepScore.keyFindings)
                    
                    // Detailed Metrics
                    DetailedMetricsCard(details: sleepScore.details)
                }
                .padding()
            }
            .navigationTitle("Sleep Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MainScoreCard: View {
    let sleepScore: SleepScoreResult
    
    var scoreColor: Color {
        switch sleepScore.finalScore {
        case 80...100: return .green
        case 60..<80: return .orange
        case 40..<60: return .yellow
        default: return .red
        }
    }
    
    var scoreDescription: String {
        switch sleepScore.finalScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Poor"
        }
    }
    
    var body: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("Sleep Score")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(sleepScore.finalScore)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)
                        Text(scoreDescription)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor)
                    }
                    Spacer()
                    
                    // Sleep duration
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDuration(sleepScore.details.timeAsleep))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

struct ComponentBreakdownCard: View {
    let sleepScore: SleepScoreResult
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Score Breakdown")
                    .font(.headline)
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    ComponentRow(
                        title: "Restorative Quality",
                        score: sleepScore.qualityComponent,
                        weight: "45%",
                        color: .purple,
                        description: "Deep sleep, REM, heart rate recovery"
                    )
                    
                    ComponentRow(
                        title: "Efficiency & Duration",
                        score: sleepScore.efficiencyComponent,
                        weight: "35%",
                        color: .blue,
                        description: "Sleep efficiency, optimal duration"
                    )
                    
                    ComponentRow(
                        title: "Timing & Consistency",
                        score: sleepScore.timingComponent,
                        weight: "20%",
                        color: .green,
                        description: "Schedule consistency"
                    )
                }
            }
        }
    }
}

struct ComponentRow: View {
    let title: String
    let score: Double
    let weight: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(weight)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(Int(round(score)))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
}

struct KeyFindingsCard: View {
    let findings: [String]
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    Text("Key Insights")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                if findings.isEmpty {
                    Text("No specific insights available for this sleep session.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(findings, id: \.self) { finding in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(finding)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DetailedMetricsCard: View {
    let details: SleepScoreDetails
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Detailed Metrics")
                    .font(.headline)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    MetricItem(
                        title: "Sleep Efficiency",
                        value: "\(Double(round(10 * details.sleepEfficiency * 100) / 10))%",
                        icon: "percent",
                        color: .blue
                    )
                    
                    MetricItem(
                        title: "Deep Sleep",
                        value: "\(Double(round(10 * details.deepSleepPercentage) / 10))%",
                        icon: "moon.fill",
                        color: .purple
                    )
                    
                    MetricItem(
                        title: "REM Sleep",
                        value: "\(Double(round(10 * details.remSleepPercentage) / 10))%",
                        icon: "brain.head.profile",
                        color: .orange
                    )
                    
                    if let hrDip = details.heartRateDipPercentage {
                        MetricItem(
                            title: "HR Recovery",
                            value: "\(Double(round(10 * hrDip * 100) / 10))%",
                            icon: "heart.fill",
                            color: .red
                        )
                    } else {
                        MetricItem(
                            title: "HR Recovery",
                            value: "N/A",
                            icon: "heart.fill",
                            color: .gray
                        )
                    }
                }
                
                if let bedtime = details.bedtime, let wakeTime = details.wakeTime {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sleep Schedule")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bedtime")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatTime(bedtime))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Wake Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatTime(wakeTime))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MetricItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}



 