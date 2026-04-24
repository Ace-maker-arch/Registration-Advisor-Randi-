import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View
{
    @State private var selectedCRN: String = ""
    @State private var selectedReplacementCRN: String = ""
    @State private var profile: StudentProfile?
    @State private var cardHolder: [Card] = []
    @State private var replacementOptions: [Card] = []
    @State private var modalityPreference: ModalityPreference?
    @State private var isGeneratingResponse = false
    @State private var isLoadingSwapOptions = false
    @State private var isApplyingSwap = false
    @State private var isShowingPDFPicker: Bool = false
    @State private var selectedPDFURL: URL?
    @State private var usedCRNs: Set<String> = []
    
    
    func confirmSchedule()
    {
        guard let profile else {return}//If i dont have a user profile stop everything
        
        guard let url = URL(string: "http://127.0.0.1:8000/confirm-schedule") else {return}
        
        let requestBody = ConfirmScheuleRequest(
            student_id: "YOUR_USERNAME_HERE",
            major: profile.major,
            program: profile.program,
            gpa: profile.gpa,
            current_classes: profile.in_progress_courses,
            next_semester_classes: cardHolder
        )
        
        guard let jsonData = try? JSONEncoder().encode(requestBody) else{
            print("Failed to encode confirm request")
            return
        }
        // Turn the body into json data format
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")//This tells the server i am sending json data
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request)
        {data, _, error in
            if let error = error{
                print("Confirm save failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {return}// If no data returned stop
            
            if let responseText = String(data: data, encoding: .utf8 ){
                print("Confirm response \(responseText)")
            }
            
        }.resume()
    }
    
    func convertCardsToDict() -> [[String: Any]]
    {
        return cardHolder.map { card in
            [
                "crn": card.crn,
                "course_code": card.course_code,
                "type": card.type,
                "section": [
                    "crn": card.crn,
                    "course_code": card.course_code,
                    "title": card.section.title ?? "N/A",
                    "term": card.section.term as Any,
                    "credits": card.section.credits as Any,
                    "modality": card.section.modality as Any,
                    "meeting": [
                        "start": card.section.meeting?.start as Any,
                        "end": card.section.meeting?.end as Any,
                        "days": [
                            "monday": card.section.meeting?.days?.monday as Any,
                            "tuesday": card.section.meeting?.days?.tuesday as Any,
                            "wednesday": card.section.meeting?.days?.wednesday as Any,
                            "thursday": card.section.meeting?.days?.thursday as Any,
                            "friday": card.section.meeting?.days?.friday as Any
                        ],
                        "location": card.section.meeting?.location as Any,
                        "room": card.section.meeting?.room as Any
                    ]
                ]
            ]
        }
    }

    func uploadPDF()
    {
        guard let selectedPDFURL else
        {
            return
        }

        guard let pdfData = try? Data(contentsOf: selectedPDFURL) else
        {
            return
        }

        isGeneratingResponse = true

        var request = URLRequest(url: URL(string: "http://127.0.0.1:8000/upload")!)
        request.httpMethod = "POST"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.setValue(modalityPreference?.rawValue ?? "", forHTTPHeaderField: "X-Modality-Preference")
        request.httpBody = pdfData

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        let session = URLSession(configuration: configuration)

        session.dataTask(with: request)
        { data, _, error in
            if let error = error
            {
                DispatchQueue.main.async
                {
                    self.isGeneratingResponse = false
                }
                print(error.localizedDescription)
                return
            }

            guard let data = data else
            {
                return
            }

            print(String(data: data, encoding: .utf8)!)

            do
            {
                let decodedProfile = try JSONDecoder().decode(StudentProfile.self, from: data)
                DispatchQueue.main.async
                {
                    self.profile = decodedProfile
                    self.cardHolder = decodedProfile.final_schedule
                    self.replacementOptions = []
                    self.selectedCRN = ""
                    self.selectedReplacementCRN = ""
                    self.isGeneratingResponse = false
                }
            }
            catch
            {
                print("Upload decode failed: \(error)")

                if let decodedCards = try? JSONDecoder().decode([Card].self, from: data)
                {
                    DispatchQueue.main.async
                    {
                        self.cardHolder = decodedCards
                        self.replacementOptions = []
                        self.selectedCRN = ""
                        self.selectedReplacementCRN = ""
                        self.isGeneratingResponse = false
                    }
                }
                else
                {
                    DispatchQueue.main.async
                    {
                        self.isGeneratingResponse = false
                    }
                }
            }
        }
        .resume()
    }

    func loadSwapOptions()
    {
        guard !selectedCRN.isEmpty else { return }
        guard let url = URL(string: "http://127.0.0.1:8000/swap-options") else { return }

        let body: [String: Any] = [
            "schedule": convertCardsToDict(),
            "crn": selectedCRN
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        isLoadingSwapOptions = true
        replacementOptions = []
        selectedReplacementCRN = ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request)
        { data, _, error in
            if error != nil
            {
                DispatchQueue.main.async
                {
                    self.isLoadingSwapOptions = false
                }
                return
            }

            guard let data = data else
            {
                DispatchQueue.main.async
                {
                    self.isLoadingSwapOptions = false
                }
                return
            }

            DispatchQueue.main.async
            {
                if let decoded = try? JSONDecoder().decode(SwapOptionsResponse.self, from: data)
                {
                    self.replacementOptions = decoded.options
                }
                self.isLoadingSwapOptions = false
            }
        }
        .resume()
    }

    func applySelectedSwap()
    {
        guard !selectedCRN.isEmpty else { return }
        guard !selectedReplacementCRN.isEmpty else { return }
        guard let url = URL(string: "http://127.0.0.1:8000/swap") else { return }

        let body: [String: Any] = [
            "schedule": convertCardsToDict(),
            "crn": selectedCRN,
            "replacement_crn": selectedReplacementCRN
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        isApplyingSwap = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request)
        { data, _, error in
            if error != nil
            {
                DispatchQueue.main.async
                {
                    self.isApplyingSwap = false
                }
                return
            }

            guard let data = data else
            {
                DispatchQueue.main.async
                {
                    self.isApplyingSwap = false
                }
                return
            }

            DispatchQueue.main.async
            {
                if let decoded = try? JSONDecoder().decode(SwapResponse.self, from: data)
                {
                    self.cardHolder = decoded.new_schedule
                    self.usedCRNs.insert(self.selectedCRN)
                    self.selectedCRN = ""
                    self.selectedReplacementCRN = ""
                    self.replacementOptions = []
                }

                self.isApplyingSwap = false
            }
        }
        .resume()
    }

    var filteredCards: [Card]
    {
        switch modalityPreference
        {
        case .wpOnlineOnly?:
            return cardHolder.filter
            {
                $0.section.modality == "ONLINE_ASYNC" || $0.section.modality == "ONLINE_SYNC"
            }
        case .inPersonWithAsync?:
            return cardHolder.filter
            {
                $0.section.modality == "IN_PERSON" || $0.section.modality == "ONLINE_ASYNC"
            }
        case nil:
            return cardHolder
        }
    }

    var body: some View
    {
        NavigationStack
        {
            ZStack
            {
                Color.blue.ignoresSafeArea()

                ScrollView
                {
                    VStack(spacing: 20)
                    {
                        Text("REGI")
                            .padding()
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                            .font(.largeTitle)

                        Text("Upload your Degree Works PDF to get class recommendations")
                            .frame(width: 300)
                            .foregroundColor(.red)
                            .fontWeight(.bold)

                        if let profile = profile
                        {
                            VStack(alignment: .leading, spacing: 5)
                            {
                                Text("Major: \(profile.major ?? "N/A")")
                                Text("GPA: \(profile.gpa ?? "N/A")")
                                Text("Credits Remaining: \(profile.credits_remaining ?? 0)")
                            }
                            .foregroundColor(.white)
                        }

                        ZStack
                        {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)

                            if let selectedPDFURL
                            {
                                Text("Selected PDF: \(selectedPDFURL.lastPathComponent)")
                                    .foregroundColor(.white)
                            }
                            else
                            {
                                Text("No PDF selected yet.")
                                    .foregroundColor(.gray)
                            }
                        }

                        Button("Import PDF")
                        {
                            isShowingPDFPicker = true
                        }
                        .fileImporter(isPresented: $isShowingPDFPicker, allowedContentTypes: [.pdf])
                        { result in
                            switch result
                            {
                            case .success(let url):
                                selectedPDFURL = url
                                modalityPreference = nil
                            case .failure:
                                break
                            }
                        }
                        .foregroundColor(.black)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(10)
                        .frame(width: 200)

                        Text("5 Recommended Classes")
                            .foregroundColor(.green)
                            .fontWeight(.bold)

                        if isGeneratingResponse
                        {
                            Text("AI generating response...")
                                .foregroundColor(.yellow)
                                .fontWeight(.semibold)
                        }

                        if selectedPDFURL != nil
                        {
                            VStack(spacing: 12)
                            {
                                Text("Choose Class Type Before Generating")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)

                                HStack
                                {
                                    Button("WP Online")
                                    {
                                        modalityPreference = .wpOnlineOnly
                                        uploadPDF()
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .cornerRadius(10)

                                    Button("In Person + Async")
                                    {
                                        modalityPreference = .inPersonWithAsync
                                        uploadPDF()
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.orange)
                                    .cornerRadius(10)
                                }
                            }
                        }

                        if filteredCards.isEmpty
                        {
                            Text("No recommendations yet")
                                .foregroundColor(.red)
                        }
                        else
                        {
                            ForEach(filteredCards, id: \.crn)
                            { card in
                                VStack
                                {
                                    RecommendationCardView(card: card)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedCRN == card.crn ? Color.green : Color.clear, lineWidth: 3)
                                        )

                                    Button("Select This Class")
                                    {
                                        selectedCRN = card.crn
                                        replacementOptions = []
                                        selectedReplacementCRN = ""
                                    }
                                    .disabled(usedCRNs.contains(card.crn))
                                    .opacity(usedCRNs.contains(card.crn) ? 0.4 : 1.0)
                                    .foregroundColor(.white)
                                    .background(Color.green)
                                    .cornerRadius(8)
                                }
                            }

                            Text("Selected: \(selectedCRN)")
                                .foregroundColor(.yellow)

                            Button("Show Swap Options")
                            {
                                loadSwapOptions()
                            }
                            .disabled(selectedCRN.isEmpty || isLoadingSwapOptions)
                            .opacity(selectedCRN.isEmpty || isLoadingSwapOptions ? 0.5 : 1.0)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.purple)
                            .cornerRadius(10)

                            if isLoadingSwapOptions
                            {
                                Text("Loading replacement classes...")
                                    .foregroundColor(.yellow)
                            }

                            if !replacementOptions.isEmpty
                            {
                                Text("Choose a replacement class")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)

                                ForEach(replacementOptions, id: \.crn)
                                { replacement in
                                    VStack
                                    {
                                        RecommendationCardView(card: replacement)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(
                                                        selectedReplacementCRN == replacement.crn ? Color.orange : Color.clear,
                                                        lineWidth: 3
                                                    )
                                            )

                                        Button("Swap In This Class")
                                        {
                                            selectedReplacementCRN = replacement.crn
                                        }
                                        .foregroundColor(.white)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                    }
                                }
                            }

                            if !selectedReplacementCRN.isEmpty
                            {
                                Text("Replacement Selected: \(selectedReplacementCRN)")
                                    .foregroundColor(.orange)
                            }

                            Button("Confirm Swap")
                            {
                                applySelectedSwap()
                            }
                            .disabled(selectedCRN.isEmpty || selectedReplacementCRN.isEmpty || isApplyingSwap)
                            .opacity(selectedCRN.isEmpty || selectedReplacementCRN.isEmpty || isApplyingSwap ? 0.5 : 1.0)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(10)

                            if isApplyingSwap
                            {
                                Text("Applying selected swap...")
                                    .foregroundColor(.yellow)
                            }
                            
                            Button("Confirm Recommended Classes")
                            {
                                confirmSchedule()
                            }
                            .foregroundColor(.red)
                            .background(Color.green)
                            .cornerRadius(10)
                        }

                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
}
