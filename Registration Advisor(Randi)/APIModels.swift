import SwiftUI

struct StudentProfile: Decodable
{
    let major: String?
    let program: String?
    let gpa: String?
    let credits_remaining: Int?
    let in_progress_courses: [Card]
    let final_schedule: [Card]
}

struct SwapResponse: Decodable
{
    let new_schedule: [Card]
}

struct SwapOptionsResponse: Decodable
{
    let options: [Card]
}

struct ScheduleResponse: Decodable // This get the response from the upload-schedule
{
    let current_courses: [Card]
}

enum ModalityPreference: String, CaseIterable
{
    case wpOnlineOnly = "WP Online Only"
    case inPersonWithAsync = "In Person + Async"
}

struct CurrentCourse: Codable
{
    let course_number: String?
    let course_name: String?
    let grade: String?
    let credits: String?
    let term: String?
}

struct ConfirmScheuleRequest: Codable// This is the exact body swift send to fastAPI
{
    let student_id: String
    let major: String?
    let program: String?
    let gpa: String?
    let current_classes: [Card]
    let next_semester_classes: [Card]
}
