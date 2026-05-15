#!/bin/bash
# Aggiorna automaticamente il build number basandosi su timestamp YYYYMMDDHHMM
# Esempio: 15 maggio 2026 ore 19:30 -> 2605151930
NEW_BUILD_NUMBER=$(date +"%y%m%d%H%M")
echo "Setting build number to: $NEW_BUILD_NUMBER"

# Sostituisce la parte dopo il "+" in pubspec.yaml
sed -i.bak -E "s/(version: [0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+/\1+$NEW_BUILD_NUMBER/" pubspec.yaml
rm pubspec.yaml.bak

echo "Updated pubspec.yaml:"
grep "version:" pubspec.yaml
