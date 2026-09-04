# Duplicate Issue Detection Tool

## Overview

This repository now includes a tool to help identify duplicate issues. With over 1200 open issues, finding duplicates manually is challenging. This tool automates the process using intelligent similarity detection.

## Quick Start

### Prerequisites
- Python 3.7 or higher
- `requests` library (will be installed automatically)
- (Optional) GitHub Personal Access Token for higher API rate limits

### Installation

```bash
cd tools
pip install -r requirements.txt
```

### Basic Usage

```bash
# Run with default settings (analyzes all open issues)
python tools/find-duplicates.py

# Or use the helper script
cd tools && ./run.sh
```

### Custom Analysis

```bash
# Analyze only recent 200 issues with a lower threshold
python tools/find-duplicates.py --max-issues 200 --threshold 0.6

# Use a GitHub token for higher rate limits
python tools/find-duplicates.py --token YOUR_TOKEN

# Save results to a custom location
python tools/find-duplicates.py --output results/my-analysis.json
```

## How It Works

The tool analyzes issues using multiple similarity metrics:

1. **Title Similarity (50% weight)**: Compares issue titles using sequence matching
2. **Body Similarity (20% weight)**: Analyzes first 500 characters of issue descriptions
3. **Label Similarity (15% weight)**: Compares issue labels (bug, feature request, etc.)
4. **Keyword Similarity (15% weight)**: Detects WebView2-specific keywords

### Smart Normalization
- Removes URLs, code blocks, and version numbers
- Extracts domain-specific keywords (crash, navigation, scaling, DPI, etc.)
- Normalizes text for better comparison

## Understanding Results

The tool generates two output files:

### 1. JSON File (machine-readable)
Contains detailed similarity scores and metadata for programmatic processing.

### 2. Text Report (human-readable)
Easy-to-read report with:
- Duplicate groups sorted by number of duplicates
- Similarity scores and breakdowns
- Direct links to all issues
- Labels and creation dates

### Example Report Section

```
Group 1: 3 potential duplicates
--------------------------------------------------------------------------------
Primary Issue: #5247
Title: [Problem/Bug]: The UI of an application appears to be frozen when user changes system Scaling
URL: https://github.com/MicrosoftEdge/WebView2Feedback/issues/5247
Created: 2025-05-19T11:39:36Z
Labels: bug

Potential Duplicates:
  - #5248 (Similarity: 85.0%)
    Title: [Problem/Bug]: The UI of an application sporadically appears to be frozen...
    URL: https://github.com/MicrosoftEdge/WebView2Feedback/issues/5248
    Breakdown: Title=0.78, Body=0.65, Labels=1.00, Keywords=0.80
```

## Interpreting Similarity Scores

- **90-100%**: Almost certainly duplicates - investigate immediately
- **80-89%**: Likely duplicates - high priority review
- **70-79%**: Possibly duplicates - manual review recommended
- **60-69%**: Might be related - check if issues describe same problem
- **Below 60%**: Likely different issues (not shown by default)

## Threshold Recommendations

| Threshold | Use Case | Expected Results |
|-----------|----------|------------------|
| 0.8-0.9 | High confidence only | Fewer results, minimal false positives |
| 0.7 (default) | Balanced approach | Good mix of recall and precision |
| 0.6-0.65 | Aggressive search | More results, some false positives |
| 0.5-0.55 | Exploratory | Many results, requires careful review |

## Workflow for Closing Duplicates

1. **Run the tool** with appropriate threshold (start with 0.7)
2. **Review the report** starting with groups with most duplicates
3. **Verify duplicates** by reading the actual issues
4. **Close duplicates** by:
   - Adding a comment linking to the original issue
   - Adding "duplicate" label
   - Closing the issue
5. **Track progress** to avoid re-analyzing closed issues

## GitHub API Rate Limits

- **Without token**: 60 requests/hour
- **With token**: 5000 requests/hour

To create a token:
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token with `public_repo` scope
3. Use with `--token` flag or set `GITHUB_TOKEN` environment variable

## Tips for Best Results

1. **Start small**: Test with `--max-issues 100` first
2. **Review manually**: The tool suggests duplicates, but human judgment is essential
3. **Check labels**: Issues with identical labels are more likely to be true duplicates
4. **Consider dates**: Usually keep the older issue and close newer ones
5. **Look for patterns**: Multiple issues from same user might need different handling
6. **Document decisions**: Add comments explaining why issues were marked as duplicates

## Common Duplicate Patterns

Based on the repository, common duplicate issues include:

- **Scaling/DPI issues**: Multiple reports of UI freezing or incorrect sizing with DPI changes
- **Navigation failures**: Various forms of navigation not working
- **Authentication issues**: Different symptoms of SSO/auth problems
- **Performance issues**: Memory leaks, crashes, freezes
- **Feature requests**: Same feature requested multiple times

## Advanced Usage

### Analyzing Specific Issue Types

```bash
# Focus on bugs only (fetch manually filtered)
# Note: The tool fetches all open issues; pre-filtering requires manual work

# Analyze with very high threshold for obvious duplicates
python tools/find-duplicates.py --threshold 0.85

# Quick analysis of recent issues
python tools/find-duplicates.py --max-issues 300 --threshold 0.7
```

### Integrating with CI/CD

The tool can be integrated into automated workflows:

```bash
# Generate report on schedule
python tools/find-duplicates.py --output reports/$(date +%Y-%m-%d)-duplicates.json
```

## Troubleshooting

### Rate Limit Errors
**Solution**: Use a GitHub token or wait for the rate limit to reset (1 hour)

### No Duplicates Found
**Solution**: Lower the threshold (try 0.6 or 0.65)

### Too Many False Positives
**Solution**: Raise the threshold (try 0.8) or focus on specific issue types

### Script Errors
**Solution**: Ensure Python 3.7+ and `requests` library are installed

## Contributing Improvements

To enhance the duplicate detection:

1. **Add keywords**: Edit `extract_keywords()` in `find-duplicates.py`
2. **Adjust weights**: Modify similarity weights in `calculate_similarity()`
3. **Improve normalization**: Enhance `normalize_text()` function
4. **Add metrics**: Implement additional similarity algorithms

## Files Created

```
tools/
├── find-duplicates.py      # Main duplicate detection script
├── README.md               # Detailed tool documentation
├── requirements.txt        # Python dependencies
├── run.sh                  # Quick start script
├── .gitignore             # Ignore output files
└── duplicate-issues.json   # Output (generated)
└── duplicate-issues.txt    # Report (generated)
```

## Support

For questions or issues with this tool:
1. Check the tool's README in `tools/README.md`
2. Review example output and threshold recommendations
3. Open an issue with the `tools` or `meta` label

## License

This tool is part of the WebView2Feedback repository and follows the same license terms.
