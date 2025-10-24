# Contributing to Multi-AI Orchestrium

First off, thank you for considering contributing to Multi-AI Orchestrium! It's people like you that make this project such a great tool.

Following these guidelines helps to communicate that you respect the time of the developers managing and developing this open source project. In return, they should reciprocate that respect in addressing your issue, assessing changes, and helping you finalize your pull requests.

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report for Multi-AI Orchestrium. Following these guidelines helps maintainers and the community understand your report, reproduce the behavior, and find related reports.

-   **Use a clear and descriptive title** for the issue to identify the problem.
-   **Describe the exact steps which reproduce the problem** in as many details as possible.
-   **Provide specific examples to demonstrate the steps.** Include links to files or GitHub projects, or copy/pasteable snippets, which you use in those examples.
-   **Describe the behavior you observed after following the steps** and point out what exactly is the problem with that behavior.
-   **Explain which behavior you expected to see instead and why.**
-   **Include screenshots and animated GIFs** which show you following the described steps and clearly demonstrate the problem.

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for Multi-AI Orchestrium, including completely new features and minor improvements to existing functionality.

-   **Use a clear and descriptive title** for the issue to identify the suggestion.
-   **Provide a step-by-step description of the suggested enhancement** in as many details as possible.
-   **Provide specific examples to demonstrate the steps.** Include copy/pasteable snippets which you use in those examples, as Markdown code blocks.
-   **Describe the current behavior** and **explain which behavior you expected to see instead** and why.
-   **Explain why this enhancement would be useful** to most Multi-AI Orchestrium users.

### Your First Code Contribution

Unsure where to begin contributing to Multi-AI Orchestrium? You can start by looking through these `beginner` and `help-wanted` issues:

-   [Beginner issues][beginner] - issues which should only require a few lines of code, and a test or two.
-   [Help wanted issues][help-wanted] - issues which should be a bit more involved than `beginner` issues.

### Pull Requests

The process described here has several goals:

-   Maintain Multi-AI Orchestrium's quality
-   Fix problems that are important to users
-   Engage the community in working toward the best possible Multi-AI Orchestrium
-   Enable a sustainable system for Multi-AI Orchestrium's maintainers to review contributions

Please follow these steps to have your contribution considered by the maintainers:

1.  **Follow all instructions in the template**
2.  **Follow the styleguides**
3.  **After you submit your pull request**, verify that all status checks are passing.

## Styleguides

### Git Commit Messages

-   Use the present tense ("Add feature" not "Added feature")
-   Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
-   Limit the first line to 72 characters or less
-   Reference issues and pull requests liberally after the first line
-   When only changing documentation, include `[ci skip]` in the commit title.

### JavaScript Styleguide

All JavaScript code is linted with [ESLint](https://eslint.org/).

-   Read the [ESLint documentation](https://eslint.org/docs/user-guide/getting-started) for more information.

### Python Styleguide

All Python code is formatted with [Black](https://github.com/psf/black).

-   Read the [Black documentation](https://black.readthedocs.io/en/stable/) for more information.

## Setup

The following steps will get you set up to contribute to Multi-AI Orchestrium:

1.  Fork the repository.
2.  Clone your fork: `git clone https://github.com/your-username/multi-ai-orchestrium.git`
3.  Install the dependencies: `pip install -r requirements.txt`
4.  Create a new branch for your changes: `git checkout -b my-new-feature`
5.  Make your changes.
6.  Run the tests: `pytest`
7.  Commit your changes: `git commit -am 'Add some feature'`
8.  Push to the branch: `git push origin my-new-feature`
9.  Create a new Pull Request.

[beginner]: https://github.com/search?q=is%3Aopen+is%3Aissue+label%3Abeginner
[help-wanted]: https://github.com/search?q=is%3Aopen+is%3Aissue+label%3Ahelp-wanted
