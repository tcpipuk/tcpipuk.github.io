# Welcome

This is my public repository of various guides and resources - it's a collection of personal notes, and hopefully my shared knowledge base may come in handy for anyone interested in tech, especially areas like server management, networking, and more.

## About this Project

This site is built from my [GitHub repository](https://github.com/tcpipuk/tcpipuk.github.io) using [mdBook](https://github.com/rust-lang/mdBook), a utility to create online books from Markdown files. It's a simple but powerful tool that lets me write in a simple format that can be quickly compiled and presented in a structured, readable format.

### How It's Built

1. **Content Structure**: All documentation is stored in the `src` directory, specified in `book.toml`.
2. **Continuous Deployment**: The `.github/workflows/mdbook.yml` file configures GitHub Actions, so whenever there's a push to the repository, GitHub Actions auto-builds the project using mdBook and deploys it to GitHub Pages.
3. **Customization**: Various CSS and JavaScript files (`src/assets/`) are included to tweak the appearance and behaviour of the site.

### Editing and Contributions

I do accept GitHub Issues and Pull Requests - feel free to propose changes or enhancements, especially if you notice anything inaccurate or needing extra clarification. You can click the edit icon on the top right of any page to jump to the GitHub editor for that file - simply fork the repo and submit a Pull Request and I'll get back to you as soon as possible.

Happy reading!
