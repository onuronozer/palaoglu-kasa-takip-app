import Social
import UIKit

class ShareViewController: SLComposeServiceViewController {
    private var didStartProcessing = false

    private var appGroupId: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
        navigationController?.setNavigationBarHidden(true, animated: false)
        DispatchQueue.main.async { [weak self] in
            self?.handleSharedContent()
        }
    }

    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        handleSharedContent()
    }

    override func configurationItems() -> [Any]! {
        []
    }

    private func handleSharedContent() {
        guard !didStartProcessing else { return }
        didStartProcessing = true

        guard let extensionContext else {
            closeShareExtension()
            return
        }

        let attachments = extensionContext.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier("public.image") }

        guard !attachments.isEmpty else {
            closeShareExtension()
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var filePaths: [(index: Int, path: String)] = []

        for (index, attachment) in attachments.enumerated() {
            group.enter()
            attachment.loadItem(
                forTypeIdentifier: "public.image",
                options: nil
            ) { [weak self] item, _ in
                defer { group.leave() }
                guard let path = self?.persistImage(item, index: index) else {
                    return
                }
                lock.lock()
                filePaths.append((index, path))
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let paths = filePaths
                .sorted { $0.index < $1.index }
                .map { $0.path }
            guard !paths.isEmpty else {
                self.closeShareExtension()
                return
            }
            self.saveShareData([
                "filePaths": paths,
                "mimeType": self.mimeType(for: paths[0]),
            ])
            self.navigateToMainApp()
        }
    }

    private func persistImage(_ item: Any?, index: Int) -> String? {
        guard let appGroupId,
              let container = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: appGroupId
              ) else {
            return nil
        }

        let directory = container.appendingPathComponent(
            "shared_receipts",
            isDirectory: true
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let name = "receipt_\(Int(Date().timeIntervalSince1970 * 1000))_\(index)"

            if let source = item as? URL {
                let fileExtension = source.pathExtension.isEmpty
                    ? "jpg"
                    : source.pathExtension.lowercased()
                let destination = directory
                    .appendingPathComponent(name)
                    .appendingPathExtension(fileExtension)
                let accessed = source.startAccessingSecurityScopedResource()
                defer {
                    if accessed { source.stopAccessingSecurityScopedResource() }
                }
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: source, to: destination)
                return destination.path
            }

            if let image = item as? UIImage,
               let data = image.jpegData(compressionQuality: 0.95) {
                let destination = directory
                    .appendingPathComponent(name)
                    .appendingPathExtension("jpg")
                try data.write(to: destination, options: .atomic)
                return destination.path
            }

            if let data = item as? Data {
                let destination = directory
                    .appendingPathComponent(name)
                    .appendingPathExtension("jpg")
                try data.write(to: destination, options: .atomic)
                return destination.path
            }
        } catch {
            return nil
        }
        return nil
    }

    private func mimeType(for path: String) -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "heic", "heif":
            return "image/heic"
        case "webp":
            return "image/webp"
        default:
            return "image/jpeg"
        }
    }

    private func saveShareData(_ data: [String: Any]) {
        guard let appGroupId,
              let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let temporaryFile = URL(fileURLWithPath: "/tmp/")
            .appendingPathComponent("share_intent_data_\(appGroupId).json")
        try? jsonData.write(to: temporaryFile, options: .atomic)

        if let defaults = UserDefaults(suiteName: appGroupId) {
            defaults.set(jsonString, forKey: "shareData")
            defaults.set([data], forKey: "ShareKey")
            defaults.set(jsonString, forKey: "SharingKeyData")
            defaults.synchronize()
        }
    }

    private func navigateToMainApp() {
        guard let bundleId = Bundle.main.object(
            forInfoDictionaryKey: "MainAppBundleId"
        ) as? String,
              let url = URL(string: "SharingMedia-\(bundleId)://") else {
            closeShareExtension()
            return
        }

        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.closeShareExtension()
                }
                return
            }
            responder = current.next
        }

        let selector = sel_registerName("openURL:")
        responder = self
        while let current = responder {
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    [weak self] in self?.closeShareExtension()
                }
                return
            }
            responder = current.next
        }
        closeShareExtension()
    }

    private func closeShareExtension() {
        extensionContext?.completeRequest(
            returningItems: nil,
            completionHandler: nil
        )
    }
}
