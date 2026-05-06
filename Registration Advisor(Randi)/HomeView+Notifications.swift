import SwiftUI
import UserNotifications

extension HomeView {
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }

    func scheduleClassNotifications(for courses: [Card]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for course in courses {
            guard let meeting = course.section.meeting else { continue }
            guard let start = meeting.start else { continue }
            guard start.count == 4,
                  let hour = Int(start.prefix(2)),
                  let minute = Int(start.suffix(2)) else { continue }

            let dayNumbers: [(Bool?, Int)] = [
                (meeting.days?.monday, 2),
                (meeting.days?.tuesday, 3),
                (meeting.days?.wednesday, 4),
                (meeting.days?.thursday, 5),
                (meeting.days?.friday, 6)
            ]

            for (isActive, weekday) in dayNumbers {
                guard isActive == true else { continue }

                scheduleNotification(
                    id: "\(course.crn)-\(weekday)-30",
                    title: "Class in 30 minutes",
                    body: "\(course.section.title ?? course.course_code) - \(meeting.location ?? "") \(meeting.room ?? "")",
                    weekday: weekday,
                    hour: hour,
                    minute: minute,
                    offsetMinutes: -30
                )

                scheduleNotification(
                    id: "\(course.crn)-\(weekday)-5",
                    title: "Class in 5 minutes",
                    body: "\(course.section.title ?? course.course_code) - \(meeting.location ?? "") \(meeting.room ?? "")",
                    weekday: weekday,
                    hour: hour,
                    minute: minute,
                    offsetMinutes: -5
                )
            }
        }
    }

    func scheduleNotification(id: String, title: String, body: String, weekday: Int, hour: Int, minute: Int, offsetMinutes: Int) {
        var totalMinutes = hour * 60 + minute + offsetMinutes
        if totalMinutes < 0 {
            totalMinutes += 24 * 60
        }

        let notifyHour = totalMinutes / 60
        let notifyMinute = totalMinutes % 60

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = notifyHour
        dateComponents.minute = notifyMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func scheduleRegistrationNotification(for date: String) {
        let cleaned = date
            .replacingOccurrences(of: "st", with: "")
            .replacingOccurrences(of: "nd", with: "")
            .replacingOccurrences(of: "rd", with: "")
            .replacingOccurrences(of: "th", with: "")
            .trimmingCharacters(in: .whitespaces)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"

        guard let registrationDate = formatter.date(from: cleaned) else {
            print("Could not parse registration date: \(date)")
            return
        }

        let components = Calendar.current.dateComponents([.month, .day], from: registrationDate)

        let content = UNMutableNotificationContent()
        content.title = "Registration Opens Today"
        content.body = "Time to register for next semester. Check your PIN number and plan your schedule!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.month = components.month
        dateComponents.day = components.day
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "registration-reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule registration notification: \(error)")
            }
        }
    }
}
