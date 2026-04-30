import SwiftUI

struct NearbyEventsView: View {
    @State private var events: [CampusEvent] = []

    private let eventsFeedURLString = "https://wpunj.campuslabs.com/engage/api/discovery/event/search?endsAfter=2026-04-29T17%3A48%3A31-04%3A00&orderByField=endsOn&orderByDirection=ascending&status=Approved&take=20&query="

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: event.imageURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure(_):
                                    Color.gray.opacity(0.2)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                        )
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    Color.gray.opacity(0.2)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.name)
                                    .font(.headline)

                                Text(event.location ?? "Location unavailable")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(formattedDate(event.startsOn, to: event.endsOn))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Button("RSVP") {
                                    handleRSVP(event)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                    }
                }
                .padding()
            }
            .navigationTitle("Nearby Events")
            .onAppear {
                loadEvents()
            }
        }
    }

    private func loadEvents() {
        guard let url = URL(string: eventsFeedURLString) else {
            print("Invalid events URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                print("Failed to load events: \(error.localizedDescription)")
                return
            }

            guard let data else {
                print("No event data returned")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(EventsResponse.self, from: data)
                DispatchQueue.main.async {
                    events = decoded.value
                }
            } catch {
                print("Failed to decode events: \(error)")
            }
        }
        .resume()
    }

    private func formattedDate(_ startDate: String, to endDate: String) -> String {
        let inputFormatter = ISO8601DateFormatter()

        guard let start = inputFormatter.date(from: startDate),
              let end = inputFormatter.date(from: endDate) else {
            return startDate
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let datePart = dateFormatter.string(from: start)
        let startTime = timeFormatter.string(from: start)
        let endTime = timeFormatter.string(from: end)

        return "\(datePart) · \(startTime) - \(endTime)"
    }
}

func handleRSVP(_ event: CampusEvent) {
    if event.location == nil {
        print("This has longitude and latitude")
    } else {
        print("RSVP for \(event.name) at \(event.location!)")
    }
}

#Preview {
    NearbyEventsView()
}
