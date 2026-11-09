import Testing
@testable import Scaffold

struct LaunchOptionsTests {
    @Test func argumentsSetTheState() {
        let options = LaunchOptions(arguments: ["app", "-DebugTab", "library", "-DebugFixture", "1",
                                                "-DebugScreen", "article:using-the-app/items"])
        #expect(options.tab == .library)
        #expect(options.fixture)
        #expect(options.screen == "article:using-the-app/items")
        #expect(!options.syncAllowed)
    }

    @Test func noArgumentsMeansTheRealApp() {
        let options = LaunchOptions(arguments: ["app"])
        #expect(options == LaunchOptions())
        #expect(!options.fixture && !options.noSync)
    }

    @Test func theTestHostNeverSyncs() {
        #expect(LaunchOptions.underTest)
        #expect(!LaunchOptions(arguments: ["app"]).syncAllowed)
    }

    @Test func anUnknownTabIsIgnored() {
        #expect(LaunchOptions(arguments: ["app", "-DebugTab", "nowhere"]).tab == nil)
    }
}
