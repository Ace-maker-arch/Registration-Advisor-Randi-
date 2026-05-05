import SwiftUI

struct LossyString: Decodable
{
    let value: String
    
    init(from decoder: any Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self)
        {
            value = stringValue
        }
        else if let intValue = try? container.decode(Int.self)
        {
            value = String(intValue)
        }
        else if let doubleValue = try? container.decode(Double.self)
        {
            value = String(doubleValue)
        }
        else
        {
            value = ""
        }
    }
}

func formatDays(_ days: Days?) ->String
{
    guard let days = days else {return "N/A"}
    
    var result: [String] = []
    
    if days.monday == true {result.append("Mon")}
    if days.tuesday == true {result.append("Tue")}
    if days.wednesday == true {result.append("Wed")}
    if days.thursday == true {result.append("Thu")}
    if days.friday == true { result.append("Fri")}
    
    return result.joined(separator: ", ")
}

struct Card: Codable//codable lets Swift convert your data types to and from external formats like JSON. Basically let you turn it into jason format and swift format. When the backend send json decode it to the card pbject as a swift object
{
    let course_code: String
    let crn: String
    let professor: String?
    let type: String
    let reason: String?
    let section: Section
    
    private enum CodingKeys: String, CodingKey
    {//These are the keys i expect in JSON  or to be reutrned from backend
        case course_code
        case crn
        case type
        case section
        case professor
        case reason
    }
    
    init(from decoder: any Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        course_code = try container.decodeIfPresent(String.self, forKey: .course_code) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        section = try container.decode(Section.self, forKey: .section)
        crn = (try? container.decode(LossyString.self, forKey: .crn).value) ?? ""
        professor = try container.decodeIfPresent(String.self, forKey: .professor)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        
    }
}

struct LossyInt: Codable
{
    let value: Int

    init(from decoder: any Decoder) throws
    {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self)
        {
            value = intValue  // already a number, use it directly
        }
        else if let stringValue = try? container.decode(String.self),
                let parsed = Int(stringValue)
        {
            value = parsed    // was a string like "4", convert to Int
        }
        else
        {
            value = 0         // fallback if nothing works
        }
    }
}

struct Section: Codable
{
    let title: String?//Means that the variable is optional it could be a value or nil
    let term: String?
    let credits: LossyInt
    
    let meeting: Meeting?
    let modality: String?
    let all_meetings: [Meeting]?
}

struct Meeting: Codable
{
    let start: String?
    let end: String?
    let days: Days?
    let location: String?
    let room: String?
}

struct Days: Codable{
    let monday: Bool?
    let tuesday: Bool?
    let wednesday: Bool?
    let thursday: Bool?
    let friday: Bool?
}

struct RecommendationCardView: View//This will draw each card in the UI.
{
    let card: Card
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 20)//Makes the text appear on the left
        {
            Text(card.course_code)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
            Text(card.section.title ?? "No Title")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Professor: \(card.professor ?? "No professor found")")
                .font(.subheadline)
                .foregroundColor(.purple)
            if let reason = card.reason, !reason.isEmpty//Only run this code if the card has a reason and the reason is not blank
            {
                Text("Why this class: \(reason)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let meetings = card.section.all_meetings, !meetings.isEmpty {
                ForEach(meetings.indices, id: \.self) { i in
                    let meeting = meetings[i]
                    if meetings.count > 1 {
                        let isOnline = meeting.location?.uppercased().contains("ONLINE") == true || meeting.room?.uppercased().contains("ASYN") == true
                        let hasOnlineMeeting = meetings.contains { $0.location?.uppercased().contains("ONLINE") == true || $0.room?.uppercased().contains("ASYN") == true }
                        let hasInPersonMeeting = meetings.contains { $0.location?.uppercased().contains("ONLINE") != true && $0.room?.uppercased().contains("ASYN") != true }
                        let isMixedMode = hasOnlineMeeting && hasInPersonMeeting

                        let label: String = isMixedMode ? (isOnline ? "Online:" : "In Person:") : (i == 0 ? "Lab:" : "Lecture:")

                        Text(label)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                    Text("Time: \(meeting.start ?? "N/A") - \(meeting.end ?? "N/A")")
                    Text("Days: \(formatDays(meeting.days))")
                    Text("Location: \(meeting.location ?? "N/A")")
                    Text("Room: \(meeting.room ?? "N/A")")
                }
            } else if let meeting = card.section.meeting {
                Text("Time: \(meeting.start ?? "N/A") - \(meeting.end ?? "N/A")")
                Text("Days: \(formatDays(meeting.days))")
                Text("Location: \(meeting.location ?? "N/A")")
                Text("Room: \(meeting.room ?? "N/A")")
            }
            
            
            Text("Mode : \(card.section.modality ?? "Unknown")")
                .foregroundColor(card.section.modality == "ONLINE_ASYNC" ? .green: .blue)
            
            Text("CRN: \(card.crn)")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}
