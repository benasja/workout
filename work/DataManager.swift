import Foundation
import SwiftData

@MainActor
class DataManager: ObservableObject {
    private var _modelContext: ModelContext
    
    // Public accessor for seeding data
    var modelContext: ModelContext {
        return _modelContext
    }

    // MARK: - Published Properties for UI Updates
    @Published var currentSupplementRecord: DailySupplementRecord?
    @Published var currentJournalEntry: DailyJournal?
    @Published var currentHydrationLog: HydrationLog?
    
    // MARK: - Fitness Published Properties
    @Published var exercises: [ExerciseDefinition] = []
    @Published var workoutPrograms: [WorkoutProgram] = []
    @Published var workoutSessions: [WorkoutSession] = []
    @Published var currentWorkoutSession: WorkoutSession?
    
    init(modelContext: ModelContext) {
        self._modelContext = modelContext
    }

    // MARK: - Supplement Methods
    
    func fetchSupplementRecord(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<DailySupplementRecord> { record in
            record.date >= startOfDay && record.date < endOfDay
        }
        
        let descriptor = FetchDescriptor<DailySupplementRecord>(predicate: predicate)
        
        do {
            let records = try _modelContext.fetch(descriptor)
            currentSupplementRecord = records.first
        } catch {
            print("❌ Failed to fetch supplement record for \(date): \(error)")
            currentSupplementRecord = nil
        }
    }
    
    func toggleSupplement(_ supplementName: String, for date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let record: DailySupplementRecord
        if let existingRecord = currentSupplementRecord {
            record = existingRecord
        } else {
            record = DailySupplementRecord(date: startOfDay)
            _modelContext.insert(record)
            currentSupplementRecord = record
        }
        
        if let index = record.takenSupplements.firstIndex(of: supplementName) {
            record.takenSupplements.remove(at: index)
        } else {
            record.takenSupplements.append(supplementName)
        }
        
        try save()
    }

    func isSupplementTaken(_ supplementName: String) -> Bool {
        return currentSupplementRecord?.takenSupplements.contains(supplementName) ?? false
    }

    // MARK: - Journal Methods
    
    func fetchJournalEntry(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<DailyJournal> { record in
            record.date >= startOfDay && record.date < endOfDay
        }
        let descriptor = FetchDescriptor<DailyJournal>(predicate: predicate)
        
        do {
            let entries = try _modelContext.fetch(descriptor)
            currentJournalEntry = entries.first
        } catch {
            print("❌ Failed to fetch journal entry for \(date): \(error)")
            currentJournalEntry = nil
        }
    }
    
    func saveJournalEntry(for date: Date, tags: Set<String>, notes: String) throws {
        let entry: DailyJournal
        if let existingEntry = currentJournalEntry {
            entry = existingEntry
        } else {
            entry = DailyJournal(date: date)
            _modelContext.insert(entry)
            currentJournalEntry = entry
        }
        
        entry.selectedTags = Array(tags)
        entry.notes = notes.isEmpty ? nil : notes
        
        // --- Note: The logic for legacy booleans from the old manager is preserved here ---
        let tagEnums = tags.compactMap { JournalTag(rawValue: $0) }
        let tagSet = Set(tagEnums)
        
        entry.consumedAlcohol = tagSet.contains(.alcohol)
        entry.caffeineAfter2PM = tagSet.contains(.caffeine) || tagSet.contains(.coffee)
        entry.ateLate = tagSet.contains(.lateEating)
        entry.highStressDay = tagSet.contains(.stress)
        entry.alcohol = tagSet.contains(.alcohol)
        entry.illness = tagSet.contains(.illness)
        
        if tagSet.contains(.poorSleep) {
            entry.wellness = .poor
        } else if tagSet.contains(.goodSleep) {
            entry.wellness = .excellent
        } else {
            entry.wellness = nil
        }
        // --- End of legacy boolean logic ---
        
        try save()
    }
    
    // MARK: - Hydration Methods
    
    private let globalHydrationGoalKey = "GlobalHydrationGoalInML"
    
    func getGlobalHydrationGoal() -> Int {
        UserDefaults.standard.integer(forKey: globalHydrationGoalKey) == 0 ? 2500 : UserDefaults.standard.integer(forKey: globalHydrationGoalKey)
    }
    
    func setGlobalHydrationGoal(_ newGoal: Int) {
        UserDefaults.standard.set(newGoal, forKey: globalHydrationGoalKey)
    }
    
    func fetchHydrationLog(for date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<HydrationLog> { log in
            log.date >= startOfDay && log.date < endOfDay
        }
        let descriptor = FetchDescriptor<HydrationLog>(predicate: predicate)
        
        do {
            let logs = try _modelContext.fetch(descriptor)
            if let log = logs.first {
                currentHydrationLog = log
            } else {
                // Use global goal if no log exists
                let newLog = HydrationLog(date: startOfDay, currentIntakeInML: 0, goalInML: getGlobalHydrationGoal())
                _modelContext.insert(newLog)
                currentHydrationLog = newLog
                try save()
            }
        } catch {
            print("❌ Failed to fetch hydration log for \(date): \(error)")
            currentHydrationLog = nil
        }
    }
    
    func addWater(amountInML: Int, for date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let log: HydrationLog
        if let existingLog = currentHydrationLog, calendar.isDate(existingLog.date, inSameDayAs: startOfDay) {
            log = existingLog
        } else {
            log = HydrationLog(date: startOfDay, currentIntakeInML: 0, goalInML: getGlobalHydrationGoal())
            _modelContext.insert(log)
            currentHydrationLog = log
        }
        
        log.currentIntakeInML += amountInML
        try save()
    }

    func updateHydrationGoal(newGoal: Int, for date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let log: HydrationLog
        if let existingLog = currentHydrationLog, calendar.isDate(existingLog.date, inSameDayAs: startOfDay) {
            log = existingLog
        } else {
            log = HydrationLog(date: startOfDay)
            _modelContext.insert(log)
            currentHydrationLog = log
        }
        log.goalInML = newGoal
        try save()
    }

    func updateHydrationGoalForAllDays(newGoal: Int) throws {
        setGlobalHydrationGoal(newGoal)
        let fetchDescriptor = FetchDescriptor<HydrationLog>()
        do {
            let logs = try _modelContext.fetch(fetchDescriptor)
            for log in logs {
                log.goalInML = newGoal
            }
            try save()
        } catch {
            print("❌ Failed to update hydration goal for all days: \(error)")
        }
    }

    func resetHydrationIntake(for date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let log: HydrationLog
        if let existingLog = currentHydrationLog, calendar.isDate(existingLog.date, inSameDayAs: startOfDay) {
            log = existingLog
        } else {
            log = HydrationLog(date: startOfDay, currentIntakeInML: 0, goalInML: getGlobalHydrationGoal())
            _modelContext.insert(log)
            currentHydrationLog = log
        }
        log.currentIntakeInML = 0
        try save()
    }

    // MARK: - Fitness Methods
    
    func fetchExercises() {
        let descriptor = FetchDescriptor<ExerciseDefinition>(sortBy: [SortDescriptor(\.name)])
        do {
            exercises = try _modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch exercises: \(error)")
            exercises = []
        }
    }
    
    func fetchWorkoutPrograms() {
        let descriptor = FetchDescriptor<WorkoutProgram>(sortBy: [SortDescriptor(\.name)])
        do {
            workoutPrograms = try _modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch workout programs: \(error)")
            workoutPrograms = []
        }
    }
    
    func fetchWorkoutSessions() {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            workoutSessions = try _modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch workout sessions: \(error)")
            workoutSessions = []
        }
    }
    
    func createExercise(name: String, bodyPart: String, category: String) throws -> ExerciseDefinition {
        let exercise = ExerciseDefinition(
            name: name,
            instructions: "",
            primaryMuscleGroup: bodyPart,
            equipment: category,
            userCreated: true
        )
        _modelContext.insert(exercise)
        try save()
        fetchExercises()
        return exercise
    }
    
    func createWorkoutProgram(name: String, exercises: [ExerciseDefinition] = []) throws -> WorkoutProgram {
        let program = WorkoutProgram(name: name)
        program.exercises = exercises
        _modelContext.insert(program)
        try save()
        fetchWorkoutPrograms()
        return program
    }
    
    func startWorkout(program: WorkoutProgram? = nil) throws -> WorkoutSession {
        // Prevent overlapping sessions
        if let current = currentWorkoutSession, !current.isCompleted {
            throw NSError(domain: "work", code: 1, userInfo: [NSLocalizedDescriptionKey: "A workout is already in progress. Please end it before starting a new one."])
        }
        
        let session = WorkoutSession(
            date: Date(),
            duration: 0,
            programName: program?.name
        )
        _modelContext.insert(session)
        
        // If starting from a program, add all program exercises
        if let program = program {
            for exercise in program.exercises {
                let completedExercise = CompletedExercise(exercise: exercise)
                completedExercise.workoutSession = session
                session.completedExercises.append(completedExercise)
                _modelContext.insert(completedExercise)
                // Optionally, pre-fill with a default set (comment out if not wanted):
                /*
                let defaultSet = WorkoutSet(weight: 0, reps: 0, date: Date())
                defaultSet.completedExercise = completedExercise
                _modelContext.insert(defaultSet)
                completedExercise.sets.append(defaultSet)
                session.sets.append(defaultSet)
                */
            }
        }
        currentWorkoutSession = session
        try save()
        return session
    }
    
    func endWorkout() throws {
        guard let session = currentWorkoutSession else { return }
        session.isCompleted = true
        session.duration = Date().timeIntervalSince(session.date)
        currentWorkoutSession = nil
        try save()
        fetchWorkoutSessions()
    }
    
    func addSetToWorkout(exercise: ExerciseDefinition, weight: Double, reps: Int, setType: SetType = .working) throws {
        guard let session = currentWorkoutSession else { return }
        
        let set = WorkoutSet(
            weight: weight,
            reps: reps,
            date: Date(),
            setType: setType,
            exercise: exercise
        )
        
        // Find or create completed exercise
        let completedExercise: CompletedExercise
        if let existing = session.completedExercises.first(where: { $0.exercise?.id == exercise.id }) {
            completedExercise = existing
        } else {
            completedExercise = CompletedExercise(exercise: exercise)
            completedExercise.workoutSession = session
            session.completedExercises.append(completedExercise)
            _modelContext.insert(completedExercise)
        }
        
        set.completedExercise = completedExercise
        session.sets.append(set)
        _modelContext.insert(set)
        try save()
    }
    
    func getSetsForExercise(_ exercise: ExerciseDefinition) -> [WorkoutSet] {
        let descriptor = FetchDescriptor<WorkoutSet>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let allSets = try _modelContext.fetch(descriptor)
            return allSets.filter { set in
                set.exercise?.id == exercise.id
            }
        } catch {
            print("❌ Failed to fetch sets for exercise: \(error)")
            return []
        }
    }
    
    func getPersonalRecords(for exercise: ExerciseDefinition) -> (bestSet: WorkoutSet?, maxVolume: Double, estimatedOneRepMax: Double) {
        let sets = getSetsForExercise(exercise)
        
        let bestSet = sets.max { $0.e1RM < $1.e1RM }
        let estimatedOneRepMax = bestSet?.e1RM ?? 0.0
        
        // Calculate max volume per session
        let sessionVolumes = Dictionary(grouping: sets) { set in
            Calendar.current.startOfDay(for: set.date)
        }.mapValues { sets in
            sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
        }
        
        let maxVolume = sessionVolumes.values.max() ?? 0.0
        
        return (bestSet, maxVolume, estimatedOneRepMax)
    }

    // MARK: - Save Method
    
    func save() throws {
        try _modelContext.save()
    }
} 