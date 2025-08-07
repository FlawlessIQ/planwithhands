# Accessibility Documentation 🌟

This document explains how to implement and test accessibility features in the Hands app to meet WCAG 2.1 AA and Google Play accessibility guidelines.

## 🎯 Accessibility Features Implemented

### 1. Dynamic Type / Font Scaling
- **Responsive spacing**: Automatically adjusts based on user's text scale factor
- **Constraint-based layouts**: No overflow at 2.0x or 3.0x text scaling
- **LayoutBuilder integration**: Every major screen uses responsive layout patterns

### 2. Semantic Labels
- **Button semantics**: All tappable widgets have proper labels and hints
- **Header semantics**: Page headers marked for screen readers
- **Form field semantics**: Input fields have descriptive labels
- **Navigation semantics**: Sort order for non-linear UIs

### 3. Contrast Compliance
- **WCAG AA compliance**: 4.5:1 contrast ratio for normal text, 3:1 for large text
- **Automated testing**: Contrast ratios verified in tests
- **High contrast support**: Adaptive colors for accessibility needs

### 4. Touch Targets
- **Minimum size**: 44x44dp minimum touch targets enforced
- **Accessible spacing**: Adequate spacing between interactive elements

### 5. Keyboard Navigation
- **Focus traversal**: Logical tab order with FocusTraversalGroup
- **Directional navigation**: Support for arrow key navigation in forms
- **Focus indicators**: Clear visual feedback for focused elements

## 🛠 How to Use Accessibility Helper

### Import the Helper
```dart
import 'package:hands_app/utils/accessibility_helper.dart';
```

### Dynamic Spacing
```dart
// Responsive spacing that scales with text size
SizedBox(height: context.getResponsiveSpacing(16.0))

// Responsive padding
Container(
  padding: context.getResponsivePadding(EdgeInsets.all(20)),
  child: YourWidget(),
)
```

### Semantic Wrappers
```dart
// For buttons
AccessibilityHelper.wrapWithButtonSemantics(
  label: 'Save user information',
  hint: 'Double tap to save the current form data',
  onTap: () => saveUser(),
  child: ElevatedButton(...),
)

// For headers
AccessibilityHelper.wrapWithHeaderSemantics(
  label: 'User Management Section',
  child: Text('Manage Users'),
)

// For form fields
AccessibilityHelper.wrapFormField(
  label: 'Email address',
  hint: 'Enter your email address for login',
  isRequired: true,
  child: TextFormField(...),
)
```

### Touch Target Enforcement
```dart
AccessibilityHelper.ensureMinTouchTarget(
  child: IconButton(...),
)
```

### Responsive Layouts
```dart
AccessibilityHelper.responsiveLayout(
  context: context,
  builder: (context, constraints, textScaleFactor) {
    return Column(
      children: [
        // Your widgets that adapt to text scale
      ],
    );
  },
)
```

### Focus Navigation
```dart
AccessibilityHelper.createFocusTraversalGroup(
  child: Form(
    child: Column(
      children: [
        // Form fields with proper tab order
      ],
    ),
  ),
)
```

## 🧪 Running Accessibility Tests

### Contrast Tests
Test that all text meets WCAG AA contrast requirements:

```bash
flutter test test/accessibility_contrast_test.dart
```

### Golden Tests
Test responsive layouts at different screen sizes:

```bash
flutter test test/golden/golden_test.dart
```

### Generate Golden Files
To update golden test images:

```bash
flutter test test/golden/golden_test.dart --update-goldens
```

### Manual Testing Checklist

#### Screen Reader Testing
- **iOS**: Enable VoiceOver in Settings > Accessibility
- **Android**: Enable TalkBack in Settings > Accessibility
- **Test**: Navigate through all screens using only screen reader

#### Text Scaling Testing
- **iOS**: Settings > Display & Brightness > Text Size
- **Android**: Settings > Display > Font size
- **Test**: Verify no overflow at maximum text size

#### Contrast Testing
- **iOS**: Settings > Accessibility > Display > Increase Contrast
- **Android**: Settings > Accessibility > High contrast text
- **Test**: Verify all text is readable in high contrast mode

#### Keyboard Navigation Testing
- **External keyboard**: Connect Bluetooth keyboard to device
- **Test**: Navigate through forms using Tab/Shift+Tab

## 📱 Implementation Guidelines

### For New Widgets
1. **Wrap with LayoutBuilder** for responsive design
2. **Add semantic labels** for all interactive elements
3. **Use AccessibilityHelper methods** for consistent implementation
4. **Test with text scaling** at 2.0x and 3.0x
5. **Verify touch targets** meet 44x44dp minimum

### For Existing Widgets
1. **Audit current implementation** using accessibility scanner
2. **Add missing semantic labels** incrementally
3. **Replace fixed spacing** with responsive equivalents
4. **Test backward compatibility** with existing functionality

### Common Patterns

#### Scaffold Bodies
```dart
Scaffold(
  body: LayoutBuilder(
    builder: (context, constraints) {
      final textScaleFactor = MediaQuery.textScaleFactorOf(context);
      return SingleChildScrollView(
        padding: context.getResponsivePadding(EdgeInsets.all(16)),
        child: Column(
          children: [
            // Responsive content
          ],
        ),
      );
    },
  ),
)
```

#### Interactive Cards
```dart
AccessibilityHelper.wrapWithButtonSemantics(
  label: 'User card for John Doe',
  hint: 'Double tap to view user details',
  onTap: () => viewUserDetails(),
  child: Card(
    child: InkWell(
      onTap: () => viewUserDetails(),
      child: AccessibilityHelper.ensureMinTouchTarget(
        child: CardContent(),
      ),
    ),
  ),
)
```

#### Form Sections
```dart
AccessibilityHelper.createFocusTraversalGroup(
  child: Column(
    children: [
      AccessibilityHelper.wrapWithHeaderSemantics(
        label: 'Personal Information Section',
        child: Text('Personal Information'),
      ),
      AccessibilityHelper.wrapFormField(
        label: 'First name',
        isRequired: true,
        child: TextFormField(...),
      ),
      // More form fields...
    ],
  ),
)
```

## 🎨 Theme Integration

The accessibility helper works seamlessly with your existing HandsTheme:

```dart
// Your theme already supports:
- GoogleFonts.inter() for consistent typography
- Proper contrast ratios in color scheme
- Accessible input decoration theme
- Minimum touch target sizes in button themes
```

## 🔧 Troubleshooting

### Text Overflow Issues
- Use `Flexible` or `Expanded` widgets around text
- Implement `maxLines` with `overflow: TextOverflow.ellipsis`
- Test with text scale factor 3.0x

### Focus Issues
- Ensure all interactive widgets are focusable
- Set proper `FocusNode` relationships
- Test tab order with external keyboard

### Semantic Issues
- Use accessibility scanner in Flutter Inspector
- Test with actual screen readers on devices
- Verify labels are descriptive and contextual

## 📚 Resources

- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [Google Play Accessibility Requirements](https://support.google.com/googleplay/android-developer/answer/113476)

## 🚀 Next Steps

1. **Audit existing widgets** using the accessibility helper
2. **Run automated tests** to establish baseline
3. **Implement incrementally** starting with most-used screens
4. **Test with real users** who rely on accessibility features
5. **Monitor and maintain** accessibility as app evolves

Remember: Accessibility is not a one-time task but an ongoing commitment to inclusive design! 🌈
