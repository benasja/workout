#!/usr/bin/env swift

import Foundation

print("🔄 Testing History Order and Percentage Display Fix...")

let hydrationViewPath = "work/Views/HydrationView.swift"
guard let content = try? String(contentsOfFile: hydrationViewPath, encoding: .utf8) else {
    print("❌ Could not read HydrationView.swift")
    exit(1)
}

var fixesApplied = 0

// Test 1: Check if .reversed() was removed
if !content.contains("return historyData.reversed()") && content.contains("return historyData") {
    print("✅ Fix 1: Removed .reversed() - Today will now appear at bottom")
    fixesApplied += 1
} else {
    print("❌ Fix 1: .reversed() still present or return statement missing")
}

// Test 2: Check for improved percentage display
if content.contains(".lineLimit(1)") && content.contains(".minimumScaleFactor(0.8)") {
    print("✅ Fix 2: Added lineLimit and minimumScaleFactor for percentage display")
    fixesApplied += 1
} else {
    print("❌ Fix 2: Percentage display improvements missing")
}

// Test 3: Check for increased frame width
if content.contains(".frame(minWidth: 44") && content.contains(".frame(width: 68)") {
    print("✅ Fix 3: Increased frame widths for better percentage display")
    fixesApplied += 1
} else {
    print("❌ Fix 3: Frame width adjustments missing")
}

// Test 4: Verify the order logic in the loop
let lines = content.components(separatedBy: .newlines)
var foundCorrectOrder = false

for (index, line) in lines.enumerated() {
    if line.contains("for i in 0..<7") {
        // Check the next few lines for the correct label logic
        let nextLines = lines[index+1..<min(index+5, lines.count)]
        let nextContent = nextLines.joined(separator: "\n")
        
        if nextContent.contains("i == 0 ? \"Today\"") && 
           nextContent.contains("i == 1 ? \"Yesterday\"") &&
           nextContent.contains("\"\\(i) days ago\"") {
            foundCorrectOrder = true
            break
        }
    }
}

if foundCorrectOrder {
    print("✅ Fix 4: Correct order logic maintained (Today = i=0, Yesterday = i=1)")
    fixesApplied += 1
} else {
    print("❌ Fix 4: Order logic may be incorrect")
}

print("\n📊 Fix Results:")
print("   • Fixes applied: \(fixesApplied)/4")

if fixesApplied == 4 {
    print("\n🎉 All history order and display fixes applied!")
    print("\n📋 Expected behavior:")
    print("   • Today appears at the BOTTOM of the 7-day history")
    print("   • Yesterday appears second from bottom")
    print("   • 6 days ago appears at the TOP")
    print("   • Percentage displays on single line (e.g., '105%')")
    print("   • No line wrapping for percentage values")
} else {
    print("\n⚠️  Some fixes may be incomplete. Please review the implementation.")
}