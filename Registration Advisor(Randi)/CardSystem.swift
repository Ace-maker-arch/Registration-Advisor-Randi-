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

struct Card: Decodable//codable lets Swift convert your data types to and from external formats like JSON. Basically let you turn it into jason format and swift format. When the backend send json decode it to the card pbject as a swift object
{
    let course_code: String
    let crn: String
    let type: String
    let section: Section
    
    private enum CodingKeys: String, CodingKey
    {
        case course_code
        case crn
        case type
        case section
    }
    
    init(from decoder: any Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        course_code = try container.decodeIfPresent(String.self, forKey: .course_code) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        section = try container.decode(Section.self, forKey: .section)
        crn = (try? container.decode(LossyString.self, forKey: .crn).value) ?? ""
    }
}

struct Section: Decodable
{
    let title: String?//Means that the variable is optional it could be a value or nil
    let term: String?
    let credits: Int?
    
    let meeting: Meeting?
    let modality: String?
}

struct Meeting: Decodable
{
    let start: String?
    let end: String?
    let days: Days?
    let location: String?
    let room: String?
}

struct Days: Decodable{
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
            
            if let meeting = card.section.meeting{
                Text("Time: \(meeting.start ?? "N/A")- \(meeting.end ?? "N/A")")
                
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
