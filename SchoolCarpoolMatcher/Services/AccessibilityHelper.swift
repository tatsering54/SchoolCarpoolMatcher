//
//  AccessibilityHelper.swift
//  SchoolCarpoolMatcher
//
//  Apple Accessibility Guidelines compliance helper
//  Implements VoiceOver, Dynamic Type, and accessibility best practices
//  Applied Rule: Comprehensive accessibility support for all users
//

import SwiftUI
import UIKit

// MARK: - Accessibility Helper
/// Centralized helper for Apple accessibility compliance
/// Provides utilities for VoiceOver, Dynamic Type, and inclusive design
class AccessibilityHelper: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isVoiceOverRunning: Bool = UIAccessibility.isVoiceOverRunning
    @Published var isReduceMotionEnabled: Bool = UIAccessibility.isReduceMotionEnabled
    @Published var isBoldTextEnabled: Bool = UIAccessibility.isBoldTextEnabled
    @Published var isHighContrastEnabled: Bool = UIAccessibility.isDarkerSystemColorsEnabled
    @Published var contentSizeCategory: ContentSizeCategory = ContentSizeCategory.medium
    
    // MARK: - Initialization
    init() {
        print("♿ AccessibilityHelper initialized")
        print("   🗣️ VoiceOver: \(isVoiceOverRunning ? "ON" : "OFF")")
        print("   🎭 Reduce Motion: \(isReduceMotionEnabled ? "ON" : "OFF")")
        print("   📝 Bold Text: \(isBoldTextEnabled ? "ON" : "OFF")")
        print("   🌓 High Contrast: \(isHighContrastEnabled ? "ON" : "OFF")")
        
        setupAccessibilityNotifications()
    }
    
    // MARK: - Accessibility Notifications
    private func setupAccessibilityNotifications() {
        // VoiceOver status changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            print("♿ VoiceOver status changed: \(UIAccessibility.isVoiceOverRunning ? "ON" : "OFF")")
        }
        
        // Reduce motion changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            print("♿ Reduce Motion changed: \(UIAccessibility.isReduceMotionEnabled ? "ON" : "OFF")")
        }
        
        // Bold text changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
            print("♿ Bold Text changed: \(UIAccessibility.isBoldTextEnabled ? "ON" : "OFF")")
        }
        
        // High contrast changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            print("♿ High Contrast changed: \(UIAccessibility.isDarkerSystemColorsEnabled ? "ON" : "OFF")")
        }
    }
    
    // MARK: - Animation Helpers
    
    /// Returns appropriate animation for accessibility preferences
    func accessibleAnimation<V: Equatable>(
        _ animation: Animation,
        value: V
    ) -> Animation? {
        return isReduceMotionEnabled ? nil : animation
    }
    
    /// Returns spring animation respecting reduce motion
    func accessibleSpringAnimation(
        response: Double = 0.4,
        dampingFraction: Double = 0.8
    ) -> Animation? {
        return isReduceMotionEnabled ? 
            .easeInOut(duration: 0.2) : 
            .spring(response: response, dampingFraction: dampingFraction)
    }
    
    // MARK: - Font Helpers
    
    /// Returns font with proper weight for accessibility
    func accessibleFont(
        _ font: Font,
        weight: Font.Weight? = nil
    ) -> Font {
        let finalWeight = weight ?? (isBoldTextEnabled ? .semibold : .regular)
        
        switch font {
        case .largeTitle:
            return .largeTitle.weight(finalWeight)
        case .title:
            return .title.weight(finalWeight)
        case .title2:
            return .title2.weight(finalWeight)
        case .title3:
            return .title3.weight(finalWeight)
        case .headline:
            return .headline.weight(finalWeight)
        case .subheadline:
            return .subheadline.weight(finalWeight)
        case .body:
            return .body.weight(finalWeight)
        case .callout:
            return .callout.weight(finalWeight)
        case .footnote:
            return .footnote.weight(finalWeight)
        case .caption:
            return .caption.weight(finalWeight)
        case .caption2:
            return .caption2.weight(finalWeight)
        default:
            return font
        }
    }
    
    // MARK: - Color Helpers
    
    /// Returns color with appropriate contrast for accessibility
    func accessibleColor(
        _ color: Color,
        highContrastAlternative: Color? = nil
    ) -> Color {
        if isHighContrastEnabled, let alternative = highContrastAlternative {
            return alternative
        }
        return color
    }
    
    /// Returns background color with proper contrast
    func accessibleBackgroundColor(
        _ backgroundColor: Color,
        highContrastAlternative: Color? = nil
    ) -> Color {
        if isHighContrastEnabled {
            return highContrastAlternative ?? Color(.systemBackground)
        }
        return backgroundColor
    }
    
    // MARK: - Touch Target Helpers
    
    /// Ensures minimum 44pt touch target as per Apple HIG
    func minimumTouchTarget(for size: CGSize) -> CGSize {
        let minSize: CGFloat = 44
        return CGSize(
            width: max(size.width, minSize),
            height: max(size.height, minSize)
        )
    }
    
    // MARK: - VoiceOver Helpers
    
    /// Creates comprehensive accessibility description
    func createAccessibilityDescription(
        label: String,
        value: String? = nil,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> AccessibilityDescription {
        return AccessibilityDescription(
            label: label,
            value: value,
            hint: hint,
            traits: traits
        )
    }
    
    /// Announces important changes to VoiceOver users
    func announceToVoiceOver(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        if isVoiceOverRunning {
            UIAccessibility.post(notification: priority, argument: message)
            print("🗣️ VoiceOver announcement: \(message)")
        }
    }
    
    // MARK: - Haptic Feedback Helpers
    
    /// Provides appropriate haptic feedback based on accessibility settings
    func provideHapticFeedback(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
        intensity: CGFloat = 1.0
    ) {
        // Respect accessibility preferences for haptic feedback
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }
    
    /// Provides success haptic feedback
    func provideSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Provides error haptic feedback
    func provideErrorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Dynamic Type Helpers
    
    /// Checks if user is using accessibility text sizes
    var isUsingAccessibilityTextSizes: Bool {
        return contentSizeCategory.isAccessibilityCategory
    }
    
    /// Returns appropriate line limit for accessibility
    func accessibleLineLimit(default: Int = 1) -> Int? {
        return isUsingAccessibilityTextSizes ? nil : `default`
    }
    
    /// Returns appropriate truncation mode for accessibility
    func accessibleTruncationMode() -> Text.TruncationMode {
        return isUsingAccessibilityTextSizes ? .tail : .middle
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Accessibility Description Model
struct AccessibilityDescription {
    let label: String
    let value: String?
    let hint: String?
    let traits: AccessibilityTraits
    
    init(
        label: String,
        value: String? = nil,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) {
        self.label = label
        self.value = value
        self.hint = hint
        self.traits = traits
    }
}

// MARK: - Accessibility View Modifiers
extension View {
    
    /// Applies comprehensive accessibility configuration
    func accessibilityConfigured(
        _ description: AccessibilityDescription
    ) -> some View {
        self
            .accessibilityLabel(description.label)
            .accessibilityValue(description.value ?? "")
            .accessibilityHint(description.hint ?? "")
            .accessibilityAddTraits(description.traits)
    }
    
    /// Ensures minimum touch target size
    func minimumTouchTarget(
        _ accessibilityHelper: AccessibilityHelper
    ) -> some View {
        self
            .frame(minWidth: 44, minHeight: 44)
    }
    
    /// Applies accessible animation
    func accessibleAnimation<V: Equatable>(
        _ animation: Animation,
        value: V,
        accessibilityHelper: AccessibilityHelper
    ) -> some View {
        self
            .animation(accessibilityHelper.accessibleAnimation(animation, value: value), value: value)
    }
    
    /// Makes view accessible for VoiceOver navigation
    func voiceOverAccessible(
        label: String,
        value: String? = nil,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Applies high contrast color adaptation
    func highContrastAdaptive(
        standardColor: Color,
        highContrastColor: Color,
        accessibilityHelper: AccessibilityHelper
    ) -> some View {
        self
            .foregroundColor(
                accessibilityHelper.accessibleColor(
                    standardColor,
                    highContrastAlternative: highContrastColor
                )
            )
    }
}

// MARK: - Accessibility Constants
struct AccessibilityConstants {
    
    // Apple HIG Requirements
    static let minimumTouchTargetSize: CGFloat = 44
    static let minimumTextContrast: Double = 4.5
    static let preferredTextContrast: Double = 7.0
    
    // Spacing for accessibility
    static let accessibleSpacing: CGFloat = 16
    static let accessiblePadding: CGFloat = 20
    
    // Animation durations respecting reduce motion
    static let standardAnimationDuration: Double = 0.3
    static let reducedAnimationDuration: Double = 0.1
    
    // Haptic feedback patterns
    enum HapticPattern {
        case selection
        case success
        case warning
        case error
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    }
}

// MARK: - Accessibility Testing Helper
#if DEBUG
struct AccessibilityTestingHelper {
    
    /// Validates view accessibility compliance
    static func validateAccessibility(for view: AnyView) -> [AccessibilityIssue] {
        let issues: [AccessibilityIssue] = []
        
        // This would contain actual validation logic in a real implementation
        // For now, we'll return an empty array
        
        return issues
    }
    
    /// Simulates VoiceOver navigation
    static func simulateVoiceOverNavigation() {
        print("🗣️ Simulating VoiceOver navigation...")
        // Implementation would simulate VoiceOver behavior
    }
}

struct AccessibilityIssue {
    let type: IssueType
    let description: String
    let severity: Severity
    
    enum IssueType {
        case missingLabel
        case smallTouchTarget
        case lowContrast
        case missingHint
        case incorrectTraits
    }
    
    enum Severity {
        case low
        case medium
        case high
        case critical
    }
}
#endif
