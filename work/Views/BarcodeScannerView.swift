import SwiftUI
import VisionKit
import AVFoundation

// MARK: - Barcode Scanner View

/// A full-screen barcode scanner view that uses DataScannerViewController for barcode detection
/// Provides haptic feedback, visual indicators, and comprehensive error handling
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BarcodeScannerViewModel()
    
    let onBarcodeScanned: (String) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera view
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(
                        recognizedDataTypes: [.barcode()],
                        onBarcodeDetected: handleBarcodeDetection,
                        isScanning: $viewModel.isScanning
                    )
                    .ignoresSafeArea()
                } else {
                    UnsupportedScannerView()
                }
                
                // Overlay UI
                VStack {
                    // Top bar
                    HStack {
                        Button("Cancel") {
                            dismiss()
                            AccessibilityUtils.selectionFeedback()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .accessibilityLabel("Cancel barcode scanning")
                        .accessibilityHint("Double tap to close barcode scanner")
                        .dynamicTypeSize(maxSize: .accessibility2)
                        
                        Spacer()
                        
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                                .padding()
                                .accessibilityLabel("Processing barcode")
                        }
                    }
                    .background(Color.black.opacity(0.3))
                    
                    Spacer()
                    
                    // Scanning frame
                    ScanningFrameView()
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: AccessibilityUtils.scaledSpacing(12)) {
                        Text("Position barcode within the frame")
                            .font(.headline)
                            .foregroundColor(.white)
                            .dynamicTypeSize(maxSize: .accessibility2)
                        
                        Text("Make sure the barcode is clearly visible and well-lit")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .dynamicTypeSize(maxSize: .accessibility2)
                        
                        if AccessibilityUtils.isKeyboardNavigationActive {
                            Text("Camera will automatically detect barcodes when positioned correctly")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .dynamicTypeSize(maxSize: .accessibility2)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Barcode scanning instructions. Position barcode within the frame. Make sure the barcode is clearly visible and well-lit. Camera will automatically detect barcodes when positioned correctly")
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.requestCameraPermission()
            }
            .alert("Camera Permission Required", isPresented: $viewModel.showCameraPermissionAlert) {
                Button("Settings") {
                    viewModel.openSettings()
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Please allow camera access in Settings to scan barcodes.")
            }
            .alert("Scanning Error", isPresented: $viewModel.showErrorAlert) {
                Button("Try Again") {
                    viewModel.resetScanning()
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private func handleBarcodeDetection(_ barcode: String) {
        guard !viewModel.isProcessing else { return }
        
        viewModel.processBarcode(barcode) { success in
            if success {
                // Provide haptic feedback and accessibility announcement
                AccessibilityUtils.announceBarcodeScanSuccess()
                
                // Call the completion handler
                onBarcodeScanned(barcode)
                
                // Dismiss the scanner
                dismiss()
            }
        }
    }
}

// MARK: - Scanning Frame View

struct ScanningFrameView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Scanning frame
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    AccessibilityUtils.contrastAwareColor(
                        normal: Color.white,
                        highContrast: Color.yellow
                    ), 
                    lineWidth: AccessibilityUtils.isKeyboardNavigationActive ? 4 : 2
                )
                .frame(width: 280, height: 180)
                .accessibilityElement()
                .accessibilityLabel("Barcode scanning frame")
                .accessibilityHint("Position barcode within this frame for scanning")
            
            // Corner indicators
            VStack {
                HStack {
                    CornerIndicator(corners: [.topLeft])
                    Spacer()
                    CornerIndicator(corners: [.topRight])
                }
                Spacer()
                HStack {
                    CornerIndicator(corners: [.bottomLeft])
                    Spacer()
                    CornerIndicator(corners: [.bottomRight])
                }
            }
            .frame(width: 280, height: 180)
            
            // Scanning line animation
            Rectangle()
                .fill(Color.green)
                .frame(width: 260, height: 2)
                .offset(y: animationOffset)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        animationOffset = 80
                    }
                }
        }
    }
}

// MARK: - Corner Indicator

struct CornerIndicator: View {
    let corners: UIRectCorner
    
    var body: some View {
        RoundedCorner(radius: 4, corners: corners)
            .fill(Color.green)
            .frame(width: 20, height: 20)
    }
}

// MARK: - Rounded Corner Helper

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Unsupported Scanner View

struct UnsupportedScannerView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Scanner Not Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Barcode scanning is not supported on this device or iOS version.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Text("Please enter the barcode manually or search for the product by name.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - DataScanner Representable

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    let onBarcodeDetected: (String) -> Void
    @Binding var isScanning: Bool
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerRepresentable
        
        init(_ parent: DataScannerRepresentable) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handleRecognizedItem(item)
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Process the first barcode found
            if let firstItem = addedItems.first {
                handleRecognizedItem(firstItem)
            }
        }
        
        private func handleRecognizedItem(_ item: RecognizedItem) {
            switch item {
            case .barcode(let barcode):
                if let payloadString = barcode.payloadStringValue {
                    DispatchQueue.main.async {
                        self.parent.onBarcodeDetected(payloadString)
                    }
                }
            default:
                break
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            print("Scanner became unavailable: \(error)")
        }
    }
}

// MARK: - Barcode Scanner ViewModel

@MainActor
final class BarcodeScannerViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var isProcessing = false
    @Published var showCameraPermissionAlert = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    private var lastScannedBarcode: String?
    private var lastScanTime: Date = Date.distantPast
    private let minimumScanInterval: TimeInterval = 2.0 // Prevent duplicate scans
    
    func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startScanning()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startScanning()
                    } else {
                        self?.showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            showCameraPermissionAlert = true
        }
    }
    
    func startScanning() {
        guard DataScannerViewController.isSupported && DataScannerViewController.isAvailable else {
            showError("Barcode scanning is not supported on this device")
            return
        }
        
        isScanning = true
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    func processBarcode(_ barcode: String, completion: @escaping (Bool) -> Void) {
        // Prevent duplicate scans
        let now = Date()
        if barcode == lastScannedBarcode && now.timeIntervalSince(lastScanTime) < minimumScanInterval {
            completion(false)
            return
        }
        
        lastScannedBarcode = barcode
        lastScanTime = now
        
        // Validate barcode format
        guard isValidBarcode(barcode) else {
            showError("Invalid barcode format")
            completion(false)
            return
        }
        
        isProcessing = true
        stopScanning()
        
        // Simulate processing delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessing = false
            completion(true)
        }
    }
    
    func resetScanning() {
        isProcessing = false
        errorMessage = ""
        showErrorAlert = false
        startScanning()
    }
    
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func isValidBarcode(_ barcode: String) -> Bool {
        // Basic barcode validation
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's not empty and contains only digits
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isNumber }) else {
            return false
        }
        
        // Check common barcode lengths
        let length = trimmed.count
        let validLengths = [8, 12, 13, 14] // EAN-8, UPC-A, EAN-13, ITF-14
        
        return validLengths.contains(length)
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        stopScanning()
    }
}

// MARK: - Preview

#Preview {
    BarcodeScannerView { barcode in
        print("Scanned barcode: \(barcode)")
    }
}