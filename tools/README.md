# WebView2 Duplicate Issue Finder

This tool helps identify potential duplicate issues in the WebView2Feedback repository by analyzing issue titles, descriptions, labels, and keywords using multiple similarity algorithms.

## Features

- **Multi-metric similarity analysis**: Combines title, body, label, and keyword similarity
- **Configurable threshold**: Adjust sensitivity for duplicate detection
- **Comprehensive reports**: Generates both JSON and human-readable text reports
- **GitHub API integration**: Fetches issues directly from the repository
- **Progress tracking**: Shows analysis progress for large issue sets

## Requirements

- Python 3.7+
- `requests` library

## Installation

1. Install required dependencies:
```bash
pip install requests
```

2. (Optional) Set up a GitHub personal access token for higher rate limits:
```bash
export GITHUB_TOKEN=your_token_here
```

## Usage

### Basic Usage

Run the tool with default settings (threshold: 0.7):

```bash
python tools/find-duplicates.py
```

### Advanced Options

```bash
python tools/find-duplicates.py \
  --threshold 0.65 \
  --output results/duplicates.json \
  --max-issues 500 \
  --token YOUR_GITHUB_TOKEN
```

### Command-Line Arguments

- `--threshold FLOAT`: Similarity threshold (0-1) for considering issues as duplicates (default: 0.7)
  - Higher values (0.8-0.9): More conservative, fewer false positives
  - Lower values (0.5-0.6): More aggressive, may catch more duplicates but with false positives
  
- `--output FILE`: Output file for duplicate issues (default: duplicate-issues.json)
  - Generates both `.json` (machine-readable) and `.txt` (human-readable) files

- `--max-issues INT`: Maximum number of issues to analyze (default: all)
  - Useful for testing or analyzing recent issues only

- `--token TOKEN`: GitHub personal access token (optional)
  - Increases API rate limit from 60 to 5000 requests/hour

## Output

The tool generates two output files:

### 1. JSON File (`duplicate-issues.json`)
Machine-readable format containing:
- Primary issue details
- List of potential duplicates with similarity scores
- Similarity breakdown by metric (title, body, labels, keywords)

### 2. Text Report (`duplicate-issues.txt`)
Human-readable report including:
- Summary of duplicate groups
- Detailed information for each group
- Similarity scores and breakdowns
- Direct links to issues

## How It Works

The tool uses a weighted similarity algorithm combining:

1. **Title Similarity (50%)**: Most important factor, uses sequence matching on normalized titles
2. **Body Similarity (20%)**: Compares first 500 characters of issue descriptions
3. **Label Similarity (15%)**: Calculates Jaccard similarity of issue labels
4. **Keyword Similarity (15%)**: Extracts and compares WebView2-specific keywords

### Text Normalization
- Converts to lowercase
- Removes URLs and code blocks
- Normalizes version numbers
- Extracts domain-specific keywords

### Keywords Detected
The tool recognizes WebView2-specific terms such as:
- webview2, corewebview2
- navigation, crash, freeze, hang
- performance, memory leak
- authentication, cookie
- javascript, pdf, download, print
- devtools, fullscreen
- scaling, dpi, zoom, bounds
- event, exception, error

## Example Output

```
================================================================================
WebView2 Duplicate Issues Report
Generated: 2025-10-29 12:00:00
Total duplicate groups found: 15
================================================================================

Group 1: 3 potential duplicates
--------------------------------------------------------------------------------
Primary Issue: #5247
Title: [Problem/Bug]: The UI of an application appears to be frozen when user changes system Scaling
URL: https://github.com/MicrosoftEdge/WebView2Feedback/issues/5247
Created: 2025-05-19T11:39:36Z
Labels: bug

Potential Duplicates:
  - #5248 (Similarity: 85.0%)
    Title: [Problem/Bug]: The UI of an application sporadically appears to be frozen after opening WebView2 control
    URL: https://github.com/MicrosoftEdge/WebView2Feedback/issues/5248
    Created: 2025-05-19T11:42:51Z
    Labels: bug
    Breakdown: Title=0.78, Body=0.65, Labels=1.00, Keywords=0.80
```

## Tips for Using Results

1. **Review Manually**: The tool provides suggestions; human review is essential
2. **Check Labels**: Issues with the same labels (e.g., "bug", "tracked") are more likely to be true duplicates
3. **Compare Dates**: Older issues are typically the primary; newer ones might be duplicates
4. **Adjust Threshold**: 
   - Start with 0.7 (balanced)
   - Increase to 0.8 for high confidence only
   - Decrease to 0.6 to catch more potential duplicates
5. **Focus on Top Groups**: Groups with multiple duplicates are often more reliable

## Limitations

- **API Rate Limits**: Without a token, limited to 60 requests/hour
- **Processing Time**: Analyzing all 1200+ issues may take several minutes
- **False Positives**: Some similar issues may not be actual duplicates
- **Language**: Works best with English text
- **Version Normalization**: May over-normalize specific version-related issues

## Contributing

To improve the duplicate detection:

1. Add more WebView2-specific keywords in `extract_keywords()`
2. Adjust similarity weights in `calculate_similarity()`
3. Enhance text normalization in `normalize_text()`
4. Add new similarity metrics

## Support

For issues or questions about this tool:
1. Check existing issues in the WebView2Feedback repository
2. Open a new issue with the `tool` or `meta` label
3. Include your Python version and error messages

## License

This tool is part of the WebView2Feedback repository and follows the same license.
