import SwiftUI
import Foundation

func convertCardsToDict(_ cards: [Card]) -> [[String: Any]]
{
    return cards.map//maps is a function that loops through every element in an array and transform each one to something
    {card in
        return [
            "course_code": card.course_code,
            "crn": card.crn,
            "type": card.type,
            "section": [
                "title": card.section.title ?? "",
                "term": card.section.term ?? "",
                "credits": card.section.credits ?? 0,
                "modality": card.section.modality ?? "",
                "meeting": [
                    "start": card.section.meeting?.start ?? "", // ?. means only access start if meeting exists.
                    "end": card.section.meeting?.end ?? "",
                    "location": card.section.meeting?.location ?? "",
                    "room": card.section.meeting?.room ?? "",
                    "days": [
                        "monday": card.section.meeting?.days?.monday ?? false,
                        "tuesday": card.section.meeting?.days?.tuesday ?? false,
                        "wednesday": card.section.meeting?.days?.wednesday ?? false,
                        "thursday": card.section.meeting?.days?.thursday ?? false,
                        "friday": card.section.meeting?.days?.friday ?? false
                    ]
                ]
            ]
        ]
    }
}

func sendChatMessage(message: String, profile: StudentProfile, schedule: [Card] ) async -> String//This function is supposed to take a user message+profile, send to backend, get ai reply, return it here
{
    //This creates the endpoint where your request is going which in this case is FastAPI server
    guard let url = URL(string: "http://127.0.0.1:8000/chat") else
    {
        return "Invalid chat URL"
    }
    //Convert your swift profileinto JSON-friendly dictionary you do this because you cannot send swifts structs over the network
    let profileDict: [String: Any] = [
        "major": profile.major ?? "",
        "program": profile.program ?? "",
        "gpa": profile.gpa ?? "",
        "credits_remaining": profile.credits_remaining ?? 0,
        "final_schedule": convertCardsToDict(schedule)
    ]
    
    //Full JSON body sent to FastAPI. This basically everything that will be sent to the backend
    let body: [String: Any] = [
        "message": message,
        "profile": profileDict
    ]
    
    //Turn dictionary into JSON data raw bytes
    guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
        return "Could not convert chat request to JSON"
    }
    
    //This creates the request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    //Test FastAPI we are sending JSON type data
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    //Attach the JSON body
    request.httpBody = jsonData
    
    //Send request to backend
    do{
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)//Convert JSOn to swift object of type ChatResponse
        return decoded.reply
    } catch {
        return "Chat error: \(error.localizedDescription)"
    }
}

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
