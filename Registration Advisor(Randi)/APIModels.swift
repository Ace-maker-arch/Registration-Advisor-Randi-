import SwiftUI

struct StudentProfile: Decodable
{
    let major: String?
    let program: String?
    let student_name: String?
    let gpa: String?
    let credits_remaining: Int?
    let in_progress_courses: [Card]
    let final_schedule: [Card]
    let registration_date: String?
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
    let student_name: String?
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
    let student_name: String?
    let major: String?
    let program: String?
    let gpa: String?
    let current_classes: [Card]
    let next_semester_classes: [Card]
}

struct EventsResponse: Decodable// Decodable mean that the strucutre can be converted from json to swift
{
    let value: [CampusEvent]
}

struct CampusEvent: Decodable, Identifiable// Decodable can be converted from json. Identifiable tells SwiftUI that each CampusEvent has a unouqe id so it cna be used directly in ForEach without needing id: \.self
{
    let id: String// id is the unique identifier to each event. Because the struct conforms to identifable SwiftUi looks for a propert specifically named id to tell events apart
    let name: String
    let location: String?// Question marks make it optional, some events may not have location list
    let startsOn: String
    let endsOn: String
    let imagePath: String?
    let rsvpTotal: Int?
    let latitude: String?
    let longitude: String?

    
    var imageURL: URL?//This is a computed property that runs everytime this variable imageURL is accessed
    {//The code instide run everytime you access imageURL
        guard let imagePath, !imagePath.isEmpty else {return nil}
        return URL(string: "https://se-images.campuslabs.com/clink/images/\(imagePath)" )
    }
}
