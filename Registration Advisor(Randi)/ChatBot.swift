struct ChatResponse: Decodable
{
    let reply: String//This here matches what the ai will return from chat_with_regi
    let new_schedule: [Card]?//Sometimes there is a new schedule somestimes there is not.
    let options: [Card]?
}
