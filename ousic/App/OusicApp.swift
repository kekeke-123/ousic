import SwiftUI

@main
struct OusicApp: App {
    @StateObject private var store = ChartStore.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    guard url.pathExtension.lowercased() == "game" else { return }
                    let store = self.store
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let chart = try store.importChart(from: url)
                            DispatchQueue.main.async {
                                store.importFailed = false
                                store.importFeedback = "已导入《\(chart.title)》· \(chart.difficultyName)"
                            }
                        } catch {
                            DispatchQueue.main.async {
                                store.importFailed = true
                                store.importFeedback = "导入失败：\(error.localizedDescription)"
                            }
                        }
                    }
                }
        }
    }
}
