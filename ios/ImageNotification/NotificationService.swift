import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private var downloadTask: URLSessionDownloadTask?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    guard
      let content = request.content.mutableCopy() as? UNMutableNotificationContent
    else {
      contentHandler(request.content)
      return
    }

    bestAttemptContent = content
    guard let imageURL = Self.imageURL(from: request.content.userInfo) else {
      contentHandler(content)
      return
    }

    downloadTask = URLSession.shared.downloadTask(with: imageURL) {
      [weak self] temporaryURL, response, _ in
      guard let self else { return }
      defer { self.finish() }

      guard
        let temporaryURL,
        let httpResponse = response as? HTTPURLResponse,
        (200..<300).contains(httpResponse.statusCode)
      else {
        return
      }

      let fileExtension = imageURL.pathExtension.isEmpty
        ? "jpg"
        : imageURL.pathExtension
      let localURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(fileExtension)

      do {
        try FileManager.default.moveItem(at: temporaryURL, to: localURL)
        let attachment = try UNNotificationAttachment(
          identifier: "notification-image",
          url: localURL
        )
        content.attachments = [attachment]
      } catch {
        // Deliver the original notification if the attachment cannot be made.
      }
    }
    downloadTask?.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    downloadTask?.cancel()
    finish()
  }

  private func finish() {
    guard let contentHandler, let bestAttemptContent else { return }
    self.contentHandler = nil
    contentHandler(bestAttemptContent)
  }

  private static func imageURL(
    from userInfo: [AnyHashable: Any]
  ) -> URL? {
    if
      let options = userInfo["fcm_options"] as? [String: Any],
      let image = options["image"] as? String
    {
      return URL(string: image)
    }

    // Keep compatibility with data payloads sent by the web backend.
    if let image = userInfo["image_url"] as? String {
      return URL(string: image)
    }
    return nil
  }
}
