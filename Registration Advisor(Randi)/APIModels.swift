import SwiftUI

struct StudentProfile: Decodable
{
    let major: String?
    let program: String?
    let gpa: String?
    let credits_remaining: Int?
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

enum ModalityPreference: String, CaseIterable
{
    case wpOnlineOnly = "WP Online Only"
    case inPersonWithAsync = "In Person + Async"
}
