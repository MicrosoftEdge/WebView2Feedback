# WebView2 Best Practices

This folder documents best practices that WebView2 developers should follow when
building applications that host the WebView2 control. The goal is to capture
practical, API‑level guidance — informed by real issues that developers have run
into — so that new and existing WebView2 apps can avoid common pitfalls around
lifecycle management, navigation, security, performance, and platform
integration.

Each document focuses on a specific app model, platform, or scenario, and is
organized around two questions for every recommendation:

- **Best practice** — what you should do.
- **Why?** — the reasoning, and what can go wrong if you don't.

## Available guides

- [UWP best practices](./uwp-best-practices.md) — guidance for hosting WebView2
  inside Universal Windows Platform (UWP) applications.

## Contributing

If you have hit a problem in your own app that you think other WebView2
developers would benefit from knowing about, feel free to open an issue or a
pull request proposing a new best practice. Please keep entries:

- **API‑level and product‑agnostic** — describe the WebView2 API behavior and
  the recommended pattern, not implementation details of any specific app or
  internal product.
- **Actionable** — readers should be able to apply the guidance directly in
  their own code.
- **Justified** — always include the *Why?* so readers understand the trade‑off
  and can decide how it applies to their scenario.
