import SwiftUI

enum MoreTabDetail: Equatable {
    case none
    case recovery
    case sleep
}

class TabSelectionModel: ObservableObject {
    @Published var selection: Int = 0
    // Optionally, you can add logic to track reselects
    @Published var lastSelection: Int = 0
    @Published var moreTabDetail: MoreTabDetail = .none
} 