import Foundation
import SwiftUI

// MARK: - Font Extension for MiSans (fallback to system font)
extension Font {
    static func misans(_ weight: Font.Weight, size: CGFloat) -> Font {
        // 使用系统字体作为 MiSans 的替代
        return .system(size: size, weight: weight)
    }
}
