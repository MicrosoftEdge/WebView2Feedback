#!/bin/bash
# Quick start script for duplicate issue finder

set -e

echo "=========================================="
echo "WebView2 Duplicate Issue Finder"
echo "=========================================="
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed."
    echo "Please install Python 3.7 or higher."
    exit 1
fi

# Check if requirements are installed
echo "Checking dependencies..."
if ! python3 -c "import requests" &> /dev/null; then
    echo "Installing required packages..."
    pip3 install -r requirements.txt
else
    echo "Dependencies already installed."
fi

echo ""
echo "Starting duplicate analysis..."
echo "This may take several minutes for all issues."
echo ""

# Run the tool with default settings
python3 find-duplicates.py "$@"

echo ""
echo "=========================================="
echo "Analysis complete!"
echo "Check duplicate-issues.json and duplicate-issues.txt for results."
echo "=========================================="
