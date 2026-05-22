---
name: recipe-converter
version: 0.3.0
description: >
  Parses ingredient lists from popular recipe websites and converts
  measurements between metric and imperial units. Handles edge cases
  like volumetric-to-weight conversions for common baking ingredients.
  Supports batch scaling so users can adjust serving sizes without
  manually recalculating each ingredient.
license: MIT
platforms: macOS, iOS, visionOS
enable-caching: true
---

# Recipe Converter

A small utility for scaling and converting recipe ingredients.

## How It Works

1. Paste a URL or raw ingredient list
2. Choose your target unit system
3. Adjust the serving multiplier
4. Copy the converted list to your clipboard

## Supported Conversions

| From | To |
|---|---|
| cups | millilitres |
| ounces | grams |
| tablespoons | millilitres |
| fahrenheit | celsius |

## Notes

Volumetric-to-weight conversions depend on ingredient density, so results for things like flour or brown sugar are approximate.
