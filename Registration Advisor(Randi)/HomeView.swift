import SwiftUI
import UniformTypeIdentifiers
import UserNotifications//This is for notifications

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
    @State private var selectedTab: Int = 0 //Tracks which tab is showing. 0= next semester, 1 = current classes
    @State private var currentCourses: [Card] = []// Holds the current semester coruses form the banner
    @State private var studentName: String?
    @State private var isLoadingSchedule: Bool = false // shows loading spinner while schuedle pdf is being processed
    @State private var isShowingSchedulePicker: Bool = false // Controls whether the schedule pricker is on or not
    @State private var chatMessage: String = ""//holds what the user is tpying into the field
    @State private var chatReply: String = ""// Stores the AL's response from your backend and you use it to display the chatbot's answer on the screen
    @State private var isChatLoading: Bool = false//Tracks whether the request is in progress. To show a loading spinner while waiting for the AI response.
    
    
    func requestNotificationPermission()
    {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        {granted, error in
            if granted
            {
                print("Notification permission granted")
            }
            else//Runs if user tapped Don't Allow
            {
                print("Notification permission denies")
            }
        }
    }
    
    
    func scheduleClassNotifications(for courses: [Card])
    {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()//Removes all duplicates
        for course in courses
        {
            guard let meeting = course.section.meeting else {continue}
            guard let start = meeting.start else {continue}
            guard start.count == 4, let hour = Int(start.prefix(2)), let minute = Int(start.suffix(2)) else {continue}
            let days = meeting.days
            let dayNumbers: [(Bool?, Int)] = [//An array of tuples. Each tuple pairs the boolean with Apple's weekday number
            (days?.monday, 2),
            (days?.tuesday, 3),
            (days?.wednesday, 4),
            (days?.thursday, 5),
            (days?.friday, 6),
            ]
            for (isActive, weekday) in dayNumbers//isActive tells us if the class meet that day. Apple weekday number for that class
            {
                guard isActive == true else{continue}//If the class does not meet on this day skip to the next day.
                //30 minute remainer
                scheduleNotification(
                    id: "\(course.crn)-\(weekday)-30",
                    title: "Class in 30 minutes",
                    body: "\(course.section.title ?? course.course_code) - \(meeting.location ?? "") \(meeting.room ?? "")",
                    weekday: weekday,
                    hour: hour,
                    minute: minute,
                    offsetMinutes: -30,
                )
                
                scheduleNotification(
                               id: "\(course.crn)-\(weekday)-5",
                               title: "Class in 5 minutes",
                               body: "\(course.section.title ?? course.course_code) — \(meeting.location ?? "") \(meeting.room ?? "")",
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
        if totalMinutes < 0 { totalMinutes += 24 * 60 }

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
    
    func scheduleRegistrationNotification(for date: String)
    {
        let cleaned = date
            .replacingOccurrences(of: "st", with: "")
            .replacingOccurrences(of: "nd", with: "")
            .replacingOccurrences(of: "rd", with: "")
            .replacingOccurrences(of: "th", with: "")
            .trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()//converts between string and date
        formatter.dateFormat = "MMMM d"
        guard let regDate = formatter.date(from: cleaned) else{
            print("Could not parse registration date: \(date)")
            return
        }
        let calendar = Calendar.current//The user current calender system
        let components = calendar.dateComponents([.month, .day], from: regDate)
        let content = UNMutableNotificationContent()
        content.title = "Registration Opens Today"
        content.body = "Time register for next semester. Check your pin number and plan your schedule!"
        content.sound = .default
        var dataComponents = DateComponents()
        dataComponents.month = components.month
        dataComponents.day = components.day
        dataComponents.hour = 8
        dataComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dataComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "registration-reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule registration notification: \(error)")
                }
            }
    }
    
    func confirmSchedule()
    {
        guard let profile else {return}//If i dont have a user profile stop everything
        
        guard let url = URL(string: "http://127.0.0.1:8000/confirm-schedule") else {return}
        let resolvedStudentName = studentName ?? profile.student_name
        let resolvedStudentID =
            resolvedStudentName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "-", with: "_")
            ?? "unknown_student"
        
        print("studentName state before confirm:", studentName ?? "nil")
        print("profile.student_name before confirm:", profile.student_name ?? "nil")
        print("resolvedStudentName before confirm:", resolvedStudentName ?? "nil")
        print("currentCourses count before confirm:", currentCourses.count)
        print("cardHolder count before confirm:", cardHolder.count)
        print("CONFIRM DEBUG HIT")
        print("CONFIRM PAYLOAD student_id:", resolvedStudentID)
        print("CONFIRM PAYLOAD student_name:", resolvedStudentName ?? "nil")
        print("CONFIRM PAYLOAD currentClasses:", currentCourses.count)
        print("CONFIRM PAYLOAD nextSemester:", cardHolder.count)
        
        let requestBody = ConfirmScheuleRequest(
            student_id: resolvedStudentID,
            student_name: resolvedStudentName,
            major: profile.major,
            program: profile.program,
            gpa: profile.gpa,
            current_classes: currentCourses,
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
        
        scheduleClassNotifications(for: currentCourses)
        
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
                    "credits": card.section.credits.value as Any,  // ← extract Int from LossyInt
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
                print("decoded final_schedule count:", decodedProfile.final_schedule.count)
                for card in decodedProfile.final_schedule
                {
                    print("decoded card:", card.course_code)
                }
                DispatchQueue.main.async
                {
                    self.profile = decodedProfile
                    self.cardHolder = decodedProfile.final_schedule
                    if let regDate = decodedProfile.registration_date {  // ADD HERE
                        scheduleRegistrationNotification(for: regDate)
                    }
                    print("cardHolder count:", self.cardHolder.count)
                    for card in self.cardHolder
                    {
                        print("visible card:", card.course_code)
                    }
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
    
    //Send the banner schedule pfg to upload schedule
    func uploadSchedulePDF(_ url: URL)
    {
        // Read the pDF file into raw bytes
        guard let pdfData = try? Data(contentsOf: url) else {return}
        
        //Show loading spinner while waiting for response
        isLoadingSchedule = true
        
        // Vuuld the request to the new endpoint
        var request = URLRequest(url: URL( string: "http://127.0.0.1:8000/upload-schedule")!)
        request.httpMethod = "POST"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.httpBody = pdfData // Send raw pdf bytes, the pdf, to the server or backend
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: config)
        
        session.dataTask(with: request)
        {data, _, error in
            //  Always step spiiner when done even if there was an error
            DispatchQueue.main.async {self.isLoadingSchedule = false}
            
            guard let data = data else {return}
            
            //Decode the response into scheudleresponse, which contains current_courses
            if let decoded = try? JSONDecoder().decode(ScheduleResponse.self, from: data)// Try to turn the raw response data into a scheduleResponse. If it works put it in decoded if not fo nothing
            {
                print("SCHEDULE DEBUG HIT")
                print("decoded schedule student_name:", decoded.student_name ?? "nil")
                print("decoded current_courses count:", decoded.current_courses.count)
                print("decoded.student_name:", decoded.student_name ?? "nil")

                DispatchQueue.main.async
                {
                    // Store the current coruses so the ui can display them
                    self.studentName = decoded.student_name
                    self.currentCourses = decoded.current_courses// If we successfully understood the server response, update the UI.
                    print(studentName)
                    print(currentCourses)
                }
               
            }
        }.resume()
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
                        
                        HStack(spacing: 0)
                        {
                            // tap 0 button - enxt semster classses
                            Button("Next Semester")
                            {
                                selectedTab = 0
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            // White background hwen active, clear when inactive
                            .background(selectedTab == 0 ? Color.white.opacity(0.2): Color.clear)// vondition value_if_true: vlaue_if_false
                            .foregroundColor(.white)
                            .fontWeight(selectedTab == 0 ? .bold : .regular)
                            
                            // tab 1 button current semster classes
                            Button("Current Classes")
                            {
                                selectedTab = 1
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == 1 ? Color.white.opacity(0.2): Color.clear)
                            .foregroundColor(.white)
                            .fontWeight(selectedTab == 1 ? .bold : .regular)
                        }
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(10)
                        
                        //Show different content based on which tab is colleted
                        if selectedTab == 0
                        {
                            // Next semester tab
                            nextSemesterContent
                        }
                        else
                        {
                            // Current classes tab
                            currentClassesContent
                        }

                        Spacer()
                    }
                    .padding()
                    .onAppear()
                    {
                        requestNotificationPermission()
                    }
                }
            }
        }
    }
    
    var nextSemesterContent: some View
    {
        VStack(spacing: 20)
        {
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
                
                //Chatbot here
                VStack(alignment: .leading, spacing: 12)
                {
                    Text("Ask Regi")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Ask why a class was picked...", text: $chatMessage)//Creates an input box
                        .textFieldStyle(.roundedBorder)//Adds rounded border styling
                    Button//Defines butotn action what happens when tapped
                    {
                        guard let profile = profile else{
                            chatReply = "Upload your degree Works PDF first"
                            return
                        }
                        isChatLoading = true
                        chatReply = ""//clear old reply
                        Task//Starts async block like await content
                        {
                            let response = await sendChatMessage(//Calls your backend and waits for response
                                message: chatMessage, // send what user typed
                                profile: profile,
                                schedule: cardHolder
                                )
                            chatReply = response.reply // Stores AI response aand triggers UI update
                            
                            // Here upadtig logic happens                            
                            if let newSchedule = response.new_schedule
                            {
                                cardHolder = newSchedule
                                replacementOptions = []
                                selectedCRN = ""
                                selectedReplacementCRN = ""
                            }
                            
                            isChatLoading = false
                        }
                    } label://Defines what th ebutton looks like
                    {
                        Text(isChatLoading ? "Thinking...": "Ask Regi")//If loading thinking else ask regi
                    }
                    .disabled(chatMessage.isEmpty || isChatLoading)//Disables button if text is empty or request is already running
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(10)
                    if !chatReply.isEmpty//Only show reply if it exists
                    {
                        Text(chatReply)//Displays AI response
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                


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
                .disabled(cardHolder.isEmpty || currentCourses.isEmpty)
                .opacity(cardHolder.isEmpty || currentCourses.isEmpty ? 0.5 : 1.0)

            }
        }
    }
    
    var currentClassesContent: some View
    {
        VStack(spacing: 20)
        {
            Text("Current Semester Classes")
                .foregroundColor(.green)
                .fontWeight(.bold)

            Text("Import your Banner schedule PDF to see your exact current classes")
                .frame(width: 300)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // button opens file picker for the Banner schedule PDF
            Button("Import Schedule PDF")
            {
                isShowingSchedulePicker = true  // opens the file picker
            }
            // fileImporter shows the system file picker when isShowingSchedulePicker is true
            .fileImporter(isPresented: $isShowingSchedulePicker, allowedContentTypes: [.pdf])
            { result in
                // result is either .success(url) or .failure(error)
                if case .success(let url) = result
                {
                    uploadSchedulePDF(url)  // send PDF to backend
                }
            }
            .foregroundColor(.black)
            .background(Color.orange.opacity(0.9))
            .cornerRadius(10)
            .frame(width: 200)

            // show spinner while backend is processing the schedule PDF
            if isLoadingSchedule
            {
                Text("Loading your schedule...")
                    .foregroundColor(.yellow)
                    .fontWeight(.semibold)
            }

            // show message if no schedule loaded yet
            if currentCourses.isEmpty && !isLoadingSchedule
            {
                Text("No schedule loaded yet")
                    .foregroundColor(.red)
            }
            else
            {
                // display each current course using the exact same card view
                // as next semester — same format, same structure
                ForEach(currentCourses, id: \.crn)
                { card in
                    RecommendationCardView(card: card)
                }
            }
        }
    }
    
    
}
