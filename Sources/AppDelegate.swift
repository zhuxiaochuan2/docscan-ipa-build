import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let nav = UINavigationBar.appearance()
        nav.tintColor = Theme.primary
        nav.titleTextAttributes = [.foregroundColor: Theme.ink,
                                   .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        let large = UINavigationBarAppearance()
        large.configureWithDefaultBackground()
        large.largeTitleTextAttributes = [.foregroundColor: Theme.ink,
                                          .font: UIFont.systemFont(ofSize: 30, weight: .bold)]
        large.titleTextAttributes = [.foregroundColor: Theme.ink,
                                     .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        nav.standardAppearance = large
        nav.scrollEdgeAppearance = large
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
