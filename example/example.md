# Conalyz Examples

## Basic Usage

Analyze a Flutter project:

```bash
conalyz --path ./lib
```

## Analyze Specific File

```bash
conalyz --path lib/main.dart
```

## Web Platform Analysis

```bash
conalyz --path ./lib --platform web
```

## Custom Output Directory

```bash
conalyz --path ./lib --output ./my-reports
```

## View Usage Statistics

```bash
# Basic usage stats
conalyz usage

# Detailed usage with session history
conalyz usage --detailed
```

## Debug Mode

```bash
conalyz --path ./lib --debug
```

## Check Version

```bash
conalyz --version
```
