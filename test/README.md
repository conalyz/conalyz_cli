# Flutter Access Advisor CLI - Test Suite

This directory contains comprehensive test cases for the Flutter Access Advisor CLI tool, which analyzes Flutter applications for accessibility issues.

## Test Structure

### 1. **flutter_specific_rules_test.dart**
Tests for Flutter-specific accessibility rules including:
- `MergeSemanticsRule` - Tests proper use of MergeSemantics for logical grouping
- `TapTargetSizeRule` - Tests interactive targets meet minimum 48x48dp size
- `AnimationControlRule` - Tests animations respect reduced motion preferences
- `CustomErrorAnnouncementRule` - Tests custom errors are announced to assistive technology
- `HeadingStructureRule` - Tests semantic headings have proper hierarchy
- `TableHeadersRule` - Tests tables have proper row and cell structure
- `LiveRegionRule` - Tests dynamic content is announced to assistive technology
- `TextScalingSupportRule` - Tests text scales properly with system font size settings
- `ScaffoldNavigationRule` - Tests scaffolds have clear navigation elements
- `ExcludeSemanticsRule` - Tests proper usage of ExcludeSemantics
- `BlockSemanticsRule` - Tests proper usage of BlockSemantics

### 2. **optimized_ast_analyzer_test.dart**
Tests for core accessibility analyzer rules including:
- `ImageAccessibilityRule` - Tests images have alternative text
- `FormLabelRule` - Tests form inputs have accessible labels
- `ButtonLabelRule` - Tests buttons have proper labels
- `GestureDetectorAccessibilityRule` - Tests gesture detectors have semantic information
- `ColorContrastRule` - Tests colors meet WCAG contrast requirements
- `CheckboxAccessibilityRule` - Tests checkboxes have proper semantic information
- `ProgressIndicatorAccessibilityRule` - Tests progress indicators have semantic labels
- `EmptyTextWidgetsRule` - Tests for empty text widgets
- `VagueTextContentRule` - Tests for vague text content that lacks context

### 3. **web_rules_test.dart**
Tests for web-specific accessibility rules including:
- `WebSemanticHtmlRule` - Tests Semantics widgets have proper HTML tag mapping
- `WebAriaLabelsRule` - Tests interactive elements have proper ARIA labels
- `WebPageTitlesRule` - Tests apps have proper titles for web accessibility
- `WebFocusNavigationRule` - Tests focus elements have proper management for web

### 4. **usage_storage_service_test.dart**
Tests for usage tracking and storage functionality including:
- Storage initialization and file management
- Usage recording and retrieval
- Daily limit checking
- Error handling and recovery
- Storage path management
- Corruption handling

### 5. **usage_models_test.dart**
Tests for usage data models including:
- `UsageRecord` serialization/deserialization
- `UsageStorageData` management
- `UsageStatistics` calculation
- Daily file limit validation

### 6. **integration_test.dart**
End-to-end integration tests including:
- Single file analysis with various accessibility issues
- Project analysis with multiple files
- Platform-specific behavior (mobile vs web)
- Performance testing with large files
- Error handling for invalid files

## Running Tests

### Run All Tests
```bash
cd flutter_access_advisor_cli
flutter test
```

### Run Specific Test File
```bash
flutter test test/flutter_specific_rules_test.dart
```

### Run All Tests with Coverage
```bash
flutter test --coverage
```

### Run Tests with Verbose Output
```bash
flutter test --verbose
```

## Test Coverage

The test suite covers:

- **Accessibility Rules**: All 25+ accessibility rules with positive and negative test cases
- **Platform Support**: Both mobile and web platform-specific behaviors
- **Error Handling**: Graceful handling of malformed files, missing files, and storage errors
- **Performance**: Tests ensure the analyzer can handle large files and projects efficiently
- **Integration**: End-to-end testing of the complete analysis workflow
- **Storage**: Comprehensive testing of usage tracking and storage functionality

## Test Data

Tests use:
- **Synthetic Dart Code**: Generated Flutter widget code with known accessibility issues
- **Temporary Files**: Tests create temporary files and directories for isolation
- **Mock Data**: Usage records and statistics for testing storage functionality

## Key Test Scenarios

### Accessibility Issues Tested
- Missing alternative text for images
- Form inputs without labels
- Buttons without accessible labels
- Interactive elements without semantic information
- Poor color contrast combinations
- Missing focus management
- Inadequate tap target sizes
- Animations without reduced motion support
- Tables without proper structure
- Dynamic content without live region announcements

### Platform Differences Tested
- Web-specific ARIA requirements
- Mobile-specific touch target sizes
- Platform-specific severity levels
- Web semantic HTML mapping

### Error Conditions Tested
- Malformed Dart files
- Missing files and directories
- Storage corruption and recovery
- Permission errors
- Large file handling
- Network timeouts (simulated)

## Contributing

When adding new accessibility rules or features:

1. Add corresponding test cases in the appropriate test file
2. Include both positive (should pass) and negative (should fail) test cases
3. Test platform-specific behavior if applicable
4. Add integration tests for end-to-end scenarios
5. Ensure error handling is tested

## Test Utilities

The test files include helper functions:
- `_createWidgetInfo()` - Creates mock WidgetInfo objects for rule testing
- Temporary directory management for file-based tests
- Mock data generators for usage statistics testing