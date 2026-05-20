#!/usr/bin/env python3
"""
Example usage of the duplicate finder with sample data.
This demonstrates how the tool works without hitting API rate limits.
"""

import json
import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(__file__))

# Import directly
import importlib.util
spec = importlib.util.spec_from_file_location("find_duplicates", 
                                               os.path.join(os.path.dirname(__file__), "find-duplicates.py"))
find_duplicates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(find_duplicates)
DuplicateFinder = find_duplicates.DuplicateFinder

# Sample issues from the repository (simplified for demonstration)
sample_issues = [
    {
        "number": 5247,
        "title": "[Problem/Bug]: The UI of an application appears to be frozen when user changes system Scaling",
        "body": "When the user opens the application, changes then the windows scaling setting for his main monitor and opens the control with the webview2 afterwards, then our entire application seems to be frozen. This is related to DPI awareness.",
        "html_url": "https://github.com/MicrosoftEdge/WebView2Feedback/issues/5247",
        "created_at": "2025-05-19T11:39:36Z",
        "labels": [{"name": "bug"}]
    },
    {
        "number": 5248,
        "title": "[Problem/Bug]: The UI of an application sporadically appears to be frozen after opening WebView2 control",
        "body": "The behavior is sporadic. Application UI seems frozen. This is broken. Related to DPI and scaling issues.",
        "html_url": "https://github.com/MicrosoftEdge/WebView2Feedback/issues/5248",
        "created_at": "2025-05-19T11:42:51Z",
        "labels": [{"name": "bug"}]
    },
    {
        "number": 5406,
        "title": "[Problem/Bug]: Enabling AllowHostInputProcessing breaks Gamepad API",
        "body": "When AllowHostInputProcessing is enabled, the Gamepad API entirely stops working. This is a blocking issue.",
        "html_url": "https://github.com/MicrosoftEdge/WebView2Feedback/issues/5406",
        "created_at": "2025-10-27T14:35:09Z",
        "labels": [{"name": "bug"}]
    },
    {
        "number": 5282,
        "title": "[Problem/Bug]: The screen flash when launch a webview2 application maximize when play 4k video",
        "body": "The screen flashed when playing 4K video. This is important.",
        "html_url": "https://github.com/MicrosoftEdge/WebView2Feedback/issues/5282",
        "created_at": "2025-06-25T09:43:05Z",
        "labels": [{"name": "bug"}]
    },
    {
        "number": 5329,
        "title": "[Problem/Bug]: RasterizationScale is always reported as 1.0 and only later gets updated with correct value",
        "body": "RasterizationScale is initially reported as 1.0 while it should be larger value. DPI scaling and text scaling issues.",
        "html_url": "https://github.com/MicrosoftEdge/WebView2Feedback/issues/5329",
        "created_at": "2025-07-31T05:07:13Z",
        "labels": [{"name": "bug"}]
    }
]

def main():
    print("=" * 80)
    print("Duplicate Issue Finder - Example Usage")
    print("=" * 80)
    print()
    
    # Initialize the finder
    finder = DuplicateFinder("MicrosoftEdge", "WebView2Feedback")
    
    print(f"Analyzing {len(sample_issues)} sample issues...")
    print()
    
    # Find duplicates with different thresholds
    for threshold in [0.6, 0.7, 0.8]:
        print(f"\n--- Analysis with threshold {threshold} ---")
        duplicates = finder.find_duplicates(sample_issues, threshold=threshold)
        
        if duplicates:
            print(f"Found {len(duplicates)} duplicate groups:")
            for idx, group in enumerate(duplicates, 1):
                print(f"\nGroup {idx}:")
                print(f"  Primary: #{group['primary']['number']} - {group['primary']['title'][:60]}...")
                for dup in group['duplicates']:
                    print(f"    Duplicate: #{dup['number']} (Similarity: {dup['similarity']*100:.1f}%)")
                    print(f"      {dup['title'][:60]}...")
        else:
            print("No duplicates found at this threshold.")
    
    print("\n" + "=" * 80)
    print("Example completed!")
    print("=" * 80)
    print("\nKey findings from this sample:")
    print("- Issues #5247 and #5248 are likely duplicates (both about UI freezing with DPI/scaling)")
    print("- Issue #5329 might be related (also about scaling issues)")
    print("- Issues #5406 and #5282 appear to be unique problems")
    print("\nTo analyze all issues in the repository, run:")
    print("  python find-duplicates.py")

if __name__ == '__main__':
    main()
