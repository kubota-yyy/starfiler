import Foundation

enum TestURLFactory {
    static let root = URL(fileURLWithPath: "/")
    static let home = URL(fileURLWithPath: NSHomeDirectory())
    static let documents = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
    static let downloads = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
    static let desktop = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop", isDirectory: true)
}
