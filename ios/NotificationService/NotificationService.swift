import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            
            // Add custom sound if specified
            if let soundName = bestAttemptContent.userInfo["sound"] as? String {
                bestAttemptContent.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
            }
            
            // Add custom badge if specified
            if let badgeCount = bestAttemptContent.userInfo["badge"] as? NSNumber {
                bestAttemptContent.badge = badgeCount
            }
            
            // Handle rich media attachments
            if let attachmentURL = bestAttemptContent.userInfo["attachment-url"] as? String {
                downloadAndAttachMedia(urlString: attachmentURL) { attachment in
                    if let attachment = attachment {
                        bestAttemptContent.attachments = [attachment]
                    }
                    contentHandler(bestAttemptContent)
                }
                return
            }
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func downloadAndAttachMedia(urlString: String, completion: @escaping (UNNotificationAttachment?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            guard let location = location else {
                completion(nil)
                return
            }
            
            // Create a unique filename
            let filename = ProcessInfo.processInfo.globallyUniqueString
            let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
            
            do {
                // Move downloaded file to temp directory
                try FileManager.default.moveItem(at: location, to: fileURL)
                
                // Create notification attachment
                let attachment = try UNNotificationAttachment(identifier: filename, url: fileURL, options: nil)
                completion(attachment)
            } catch {
                print("Error creating notification attachment: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }
}
