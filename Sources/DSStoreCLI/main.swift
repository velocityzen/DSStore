import ArgumentParser

struct DSStoreCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dsstore",
        abstract: "Inspect and edit Finder .DS_Store files.",
        subcommands: [From.self, Window.self]
    )
}

DSStoreCLI.main()
