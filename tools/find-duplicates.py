#!/usr/bin/env python3
"""
WebView2 Duplicate Issue Finder

This tool helps identify potential duplicate issues in the WebView2Feedback repository.
It uses multiple similarity algorithms to find issues that might be reporting the same bug.

Usage:
    python find-duplicates.py [--threshold 0.7] [--output duplicates.json]
"""

import os
import sys
import json
import re
from collections import defaultdict
from typing import List, Dict, Tuple
import argparse
from datetime import datetime

try:
    from difflib import SequenceMatcher
    import requests
except ImportError:
    print("Error: Required packages not installed.")
    print("Please run: pip install requests")
    sys.exit(1)


class DuplicateFinder:
    """Find duplicate issues using various similarity metrics."""
    
    def __init__(self, owner: str, repo: str, token: str = None):
        self.owner = owner
        self.repo = repo
        self.token = token
        self.headers = {}
        if token:
            self.headers['Authorization'] = f'token {token}'
        self.base_url = 'https://api.github.com'
        
    def fetch_open_issues(self, max_issues: int = None) -> List[Dict]:
        """Fetch all open issues from the repository."""
        print(f"Fetching open issues from {self.owner}/{self.repo}...")
        issues = []
        page = 1
        per_page = 100
        
        while True:
            url = f'{self.base_url}/repos/{self.owner}/{self.repo}/issues'
            params = {
                'state': 'open',
                'per_page': per_page,
                'page': page,
                'filter': 'all'
            }
            
            try:
                response = requests.get(url, headers=self.headers, params=params)
                response.raise_for_status()
                page_issues = response.json()
                
                if not page_issues:
                    break
                
                # Filter out pull requests
                page_issues = [issue for issue in page_issues if 'pull_request' not in issue]
                issues.extend(page_issues)
                
                print(f"  Fetched page {page}, total issues: {len(issues)}")
                
                if max_issues and len(issues) >= max_issues:
                    issues = issues[:max_issues]
                    break
                
                page += 1
                
            except requests.exceptions.RequestException as e:
                print(f"Error fetching issues: {e}")
                break
        
        print(f"Total open issues fetched: {len(issues)}")
        return issues
    
    @staticmethod
    def normalize_text(text: str) -> str:
        """Normalize text for comparison."""
        if not text:
            return ""
        # Convert to lowercase
        text = text.lower()
        # Remove URLs
        text = re.sub(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', '', text)
        # Remove code blocks
        text = re.sub(r'```[\s\S]*?```', '', text)
        # Remove version numbers but keep the pattern
        text = re.sub(r'\d+\.\d+\.\d+(?:\.\d+)?', 'VERSION', text)
        # Remove extra whitespace
        text = ' '.join(text.split())
        return text
    
    @staticmethod
    def extract_keywords(text: str) -> set:
        """Extract important keywords from text."""
        # Common WebView2 keywords
        keywords = set()
        patterns = [
            r'webview2',
            r'corewebview2',
            r'navigation',
            r'crash',
            r'freeze',
            r'hang',
            r'performance',
            r'memory leak',
            r'authentication',
            r'cookie',
            r'javascript',
            r'pdf',
            r'download',
            r'print',
            r'devtools',
            r'fullscreen',
            r'scaling',
            r'dpi',
            r'zoom',
            r'bounds',
            r'event',
            r'exception',
            r'error',
        ]
        
        text_lower = text.lower()
        for pattern in patterns:
            if pattern in text_lower:
                keywords.add(pattern)
        
        return keywords
    
    def calculate_similarity(self, issue1: Dict, issue2: Dict) -> Tuple[float, Dict[str, float]]:
        """
        Calculate similarity between two issues.
        Returns overall score and breakdown of different metrics.
        """
        scores = {}
        
        # Title similarity (most important)
        title1 = self.normalize_text(issue1.get('title', ''))
        title2 = self.normalize_text(issue2.get('title', ''))
        scores['title'] = SequenceMatcher(None, title1, title2).ratio()
        
        # Body similarity
        body1 = self.normalize_text(issue1.get('body', ''))
        body2 = self.normalize_text(issue2.get('body', ''))
        # Use first 500 chars for body comparison (more efficient)
        scores['body'] = SequenceMatcher(None, body1[:500], body2[:500]).ratio()
        
        # Label similarity
        labels1 = set(label['name'] for label in issue1.get('labels', []))
        labels2 = set(label['name'] for label in issue2.get('labels', []))
        if labels1 or labels2:
            scores['labels'] = len(labels1 & labels2) / len(labels1 | labels2) if (labels1 | labels2) else 0
        else:
            scores['labels'] = 0
        
        # Keyword similarity
        keywords1 = self.extract_keywords(title1 + ' ' + body1)
        keywords2 = self.extract_keywords(title2 + ' ' + body2)
        if keywords1 or keywords2:
            scores['keywords'] = len(keywords1 & keywords2) / len(keywords1 | keywords2) if (keywords1 | keywords2) else 0
        else:
            scores['keywords'] = 0
        
        # Calculate weighted overall score
        overall = (
            scores['title'] * 0.5 +          # Title is most important
            scores['body'] * 0.2 +            # Body content
            scores['labels'] * 0.15 +         # Labels indicate issue type
            scores['keywords'] * 0.15         # Keywords capture key concepts
        )
        
        return overall, scores
    
    def find_duplicates(self, issues: List[Dict], threshold: float = 0.7) -> List[Dict]:
        """
        Find potential duplicate issues.
        
        Args:
            issues: List of GitHub issues
            threshold: Similarity threshold (0-1) for considering issues as duplicates
            
        Returns:
            List of duplicate groups
        """
        print(f"\nAnalyzing {len(issues)} issues for duplicates (threshold: {threshold})...")
        duplicates = []
        processed = set()
        
        for i, issue1 in enumerate(issues):
            if i in processed:
                continue
            
            if (i + 1) % 50 == 0:
                print(f"  Progress: {i+1}/{len(issues)} issues analyzed")
            
            group = {
                'primary': {
                    'number': issue1['number'],
                    'title': issue1['title'],
                    'url': issue1['html_url'],
                    'created_at': issue1['created_at'],
                    'labels': [label['name'] for label in issue1.get('labels', [])]
                },
                'duplicates': []
            }
            
            for j, issue2 in enumerate(issues[i+1:], start=i+1):
                if j in processed:
                    continue
                
                similarity, breakdown = self.calculate_similarity(issue1, issue2)
                
                if similarity >= threshold:
                    group['duplicates'].append({
                        'number': issue2['number'],
                        'title': issue2['title'],
                        'url': issue2['html_url'],
                        'created_at': issue2['created_at'],
                        'similarity': round(similarity, 3),
                        'similarity_breakdown': {k: round(v, 3) for k, v in breakdown.items()},
                        'labels': [label['name'] for label in issue2.get('labels', [])]
                    })
                    processed.add(j)
            
            if group['duplicates']:
                processed.add(i)
                duplicates.append(group)
        
        print(f"\nFound {len(duplicates)} potential duplicate groups")
        return duplicates
    
    def generate_report(self, duplicates: List[Dict], output_file: str = None):
        """Generate a human-readable report of duplicates."""
        report_lines = []
        report_lines.append("=" * 80)
        report_lines.append("WebView2 Duplicate Issues Report")
        report_lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"Total duplicate groups found: {len(duplicates)}")
        report_lines.append("=" * 80)
        report_lines.append("")
        
        # Sort by number of duplicates (descending)
        duplicates_sorted = sorted(duplicates, key=lambda x: len(x['duplicates']), reverse=True)
        
        for idx, group in enumerate(duplicates_sorted, 1):
            primary = group['primary']
            report_lines.append(f"Group {idx}: {len(group['duplicates'])} potential duplicates")
            report_lines.append("-" * 80)
            report_lines.append(f"Primary Issue: #{primary['number']}")
            report_lines.append(f"Title: {primary['title']}")
            report_lines.append(f"URL: {primary['url']}")
            report_lines.append(f"Created: {primary['created_at']}")
            report_lines.append(f"Labels: {', '.join(primary['labels']) if primary['labels'] else 'None'}")
            report_lines.append("")
            report_lines.append("Potential Duplicates:")
            
            for dup in group['duplicates']:
                report_lines.append(f"  - #{dup['number']} (Similarity: {dup['similarity']*100:.1f}%)")
                report_lines.append(f"    Title: {dup['title']}")
                report_lines.append(f"    URL: {dup['url']}")
                report_lines.append(f"    Created: {dup['created_at']}")
                report_lines.append(f"    Labels: {', '.join(dup['labels']) if dup['labels'] else 'None'}")
                breakdown = dup['similarity_breakdown']
                report_lines.append(f"    Breakdown: Title={breakdown['title']:.2f}, "
                                  f"Body={breakdown['body']:.2f}, "
                                  f"Labels={breakdown['labels']:.2f}, "
                                  f"Keywords={breakdown['keywords']:.2f}")
                report_lines.append("")
            
            report_lines.append("")
        
        report_text = "\n".join(report_lines)
        
        if output_file:
            output_txt = output_file.replace('.json', '.txt')
            with open(output_txt, 'w', encoding='utf-8') as f:
                f.write(report_text)
            print(f"\nReport saved to: {output_txt}")
        
        return report_text


def main():
    parser = argparse.ArgumentParser(
        description='Find duplicate issues in WebView2Feedback repository'
    )
    parser.add_argument(
        '--threshold',
        type=float,
        default=0.7,
        help='Similarity threshold (0-1) for considering issues as duplicates (default: 0.7)'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='duplicate-issues.json',
        help='Output file for duplicate issues (default: duplicate-issues.json)'
    )
    parser.add_argument(
        '--max-issues',
        type=int,
        default=None,
        help='Maximum number of issues to analyze (default: all)'
    )
    parser.add_argument(
        '--token',
        type=str,
        default=None,
        help='GitHub personal access token (optional, for higher rate limits)'
    )
    
    args = parser.parse_args()
    
    # Get token from environment if not provided
    token = args.token or os.environ.get('GITHUB_TOKEN')
    
    # Initialize finder
    finder = DuplicateFinder('MicrosoftEdge', 'WebView2Feedback', token)
    
    # Fetch issues
    issues = finder.fetch_open_issues(max_issues=args.max_issues)
    
    if not issues:
        print("No issues found or error fetching issues.")
        return 1
    
    # Find duplicates
    duplicates = finder.find_duplicates(issues, threshold=args.threshold)
    
    # Save to JSON
    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(duplicates, f, indent=2, ensure_ascii=False)
    print(f"\nDuplicate data saved to: {args.output}")
    
    # Generate and print report
    report = finder.generate_report(duplicates, args.output)
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    
    if duplicates:
        total_duplicates = sum(len(g['duplicates']) for g in duplicates)
        print(f"Total duplicate groups: {len(duplicates)}")
        print(f"Total potential duplicate issues: {total_duplicates}")
        print(f"\nTop 5 groups with most duplicates:")
        sorted_dupes = sorted(duplicates, key=lambda x: len(x['duplicates']), reverse=True)
        for i, group in enumerate(sorted_dupes[:5], 1):
            print(f"  {i}. Issue #{group['primary']['number']}: {len(group['duplicates'])} duplicates")
            print(f"     {group['primary']['title'][:70]}...")
    else:
        print("No duplicate issues found with the current threshold.")
        print(f"Try lowering the threshold (current: {args.threshold})")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
