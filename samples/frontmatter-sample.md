---
title: Weather Dashboard
author: Jane Park
version: 2.4.1
tags: swift, swiftui, weather, api
draft: false
---

# Weather Dashboard

A lightweight macOS app that displays real-time weather data from multiple sources.

## Architecture

The app follows a standard MVVM pattern with a shared networking layer.

```swift
struct WeatherService {
    func fetchForecast(for city: String) async throws -> Forecast {
        let url = URL(string: "https://api.example.com/weather?q=\(city)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Forecast.self, from: data)
    }
}
```

## Features

- Hourly and weekly forecast views
- Multiple location support
- Configurable units (Celsius / Fahrenheit)
- Menu bar widget with at-a-glance conditions

> Built with SwiftUI and Combine for reactive data flow.
