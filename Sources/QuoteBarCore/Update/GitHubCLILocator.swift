import Foundation

public enum GitHubCLILocator {
    public static func executablePath(
        pathEnvironment: String,
        fileExists: (String) -> Bool
    ) -> String? {
        let directories = pathEnvironment.split(separator: ":").map(String.init)
            + ["/opt/homebrew/bin", "/usr/local/bin"]
        for directory in directories {
            let candidate = "\(directory)/gh"
            if fileExists(candidate) {
                return candidate
            }
        }
        return nil
    }
}
