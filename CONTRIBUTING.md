# Contributing to SpendSmart

Thanks for your interest! SpendSmart is open source and contributions are welcome,
whether that's a bug fix, a new feature, a UI polish, or improving these docs.

The original author isn't actively developing the app anymore, so well-described,
self-contained pull requests are the best way to get changes in.

## Before you start

- Read the [Getting started](README.md#getting-started) section in the README to
  get the project building locally. You'll need **Xcode 16+** and your own
  Supabase and RevenueCat keys.
- Note the [backend caveat](README.md#getting-started): AI scanning, chat, and
  insights call a backend that isn't part of this repo. The app builds and runs
  without it, so most UI and non-AI work doesn't need a backend.

## Making a change

1. **Fork** the repo and create a branch off `main`:
   ```bash
   git checkout -b fix-something
   ```
2. **Make your change.** A few conventions to keep things consistent:
   - The app is **SwiftUI + MVVM**. Put view logic in a `ViewModel`, not the view.
   - Reuse existing building blocks: components in `Components/` and design tokens
     (colors, fonts, animations) in `Extensions/`. Avoid hardcoding colors or fonts.
   - Keep new files in the folder that matches their role (see the project
     structure in the README).
3. **Build and run** on a simulator to confirm the app still compiles and your
   change works.
4. **Open a pull request** with:
   - A short title describing the change.
   - A sentence or two on what you changed and why.
   - A screenshot or screen recording for any visible UI change.

## Reporting bugs and ideas

Found a bug or have a feature idea but don't want to write the code? Open an
[issue](https://github.com/madebyshaurya/SpendSmart/issues) and describe it.
For bugs, include steps to reproduce and your iOS version.

## Guidelines

- Keep pull requests focused. One change per PR is easier to review than ten.
- Don't commit secrets. `APIKeys.swift` is gitignored for a reason; never commit it.
- Be kind in reviews and discussions.

That's it. Thanks for helping make SpendSmart better.
