import Foundation

extension HomeView {
    func confirmSchedule() {
        guard let profile else { return }
        guard let url = URL(string: "http://127.0.0.1:8000/confirm-schedule") else { return }

        let resolvedStudentName = studentName ?? profile.student_name
        let resolvedStudentID =
            resolvedStudentName?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "-", with: "_")
            ?? "unknown_student"

        let requestBody = ConfirmScheuleRequest(
            student_id: resolvedStudentID,
            student_name: resolvedStudentName,
            major: profile.major,
            program: profile.program,
            gpa: profile.gpa,
            current_classes: currentCourses,
            next_semester_classes: cardHolder
        )

        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            print("Failed to encode confirm request")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        scheduleClassNotifications(for: currentCourses)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                print("Confirm save failed: \(error.localizedDescription)")
                return
            }

            guard let data else { return }

            if let responseText = String(data: data, encoding: .utf8) {
                print("Confirm response \(responseText)")
            }
        }
        .resume()
    }

    func uploadPDF() {
        guard let selectedPDFURL else { return }
        guard let pdfData = try? Data(contentsOf: selectedPDFURL) else { return }

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

        session.dataTask(with: request) { data, _, error in
            if let error {
                DispatchQueue.main.async {
                    isGeneratingResponse = false
                }
                print(error.localizedDescription)
                return
            }

            guard let data else { return }

            do {
                let decodedProfile = try JSONDecoder().decode(StudentProfile.self, from: data)

                DispatchQueue.main.async {
                    profile = decodedProfile
                    cardHolder = decodedProfile.final_schedule

                    if let registrationDate = decodedProfile.registration_date {
                        scheduleRegistrationNotification(for: registrationDate)
                    }

                    replacementOptions = []
                    selectedCRN = ""
                    selectedReplacementCRN = ""
                    isGeneratingResponse = false
                }
            } catch {
                print("Upload decode failed: \(error)")

                if let decodedCards = try? JSONDecoder().decode([Card].self, from: data) {
                    DispatchQueue.main.async {
                        cardHolder = decodedCards
                        replacementOptions = []
                        selectedCRN = ""
                        selectedReplacementCRN = ""
                        isGeneratingResponse = false
                    }
                } else {
                    DispatchQueue.main.async {
                        isGeneratingResponse = false
                    }
                }
            }
        }
        .resume()
    }

    func uploadSchedulePDF(_ url: URL) {
        guard let pdfData = try? Data(contentsOf: url) else { return }

        isLoadingSchedule = true

        var request = URLRequest(url: URL(string: "http://127.0.0.1:8000/upload-schedule")!)
        request.httpMethod = "POST"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.httpBody = pdfData

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: configuration)

        session.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                isLoadingSchedule = false
            }

            guard let data else { return }

            if let decoded = try? JSONDecoder().decode(ScheduleResponse.self, from: data) {
                DispatchQueue.main.async {
                    studentName = decoded.student_name
                    currentCourses = decoded.current_courses
                }
            }
        }
        .resume()
    }

    func loadSwapOptions() {
        guard !selectedCRN.isEmpty else { return }
        guard let url = URL(string: "http://127.0.0.1:8000/swap-options") else { return }

        let body: [String: Any] = [
            "schedule": convertCardsToDict(cardHolder),
            "crn": selectedCRN
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        isLoadingSwapOptions = true
        replacementOptions = []
        selectedReplacementCRN = ""
        swapStatusMessage = nil

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                DispatchQueue.main.async {
                    swapStatusMessage = "Could not load swap options."
                    isLoadingSwapOptions = false
                }
                print("Swap options request failed: \(error.localizedDescription)")
                return
            }

            guard let data else {
                DispatchQueue.main.async {
                    swapStatusMessage = "No swap options were returned."
                    isLoadingSwapOptions = false
                }
                return
            }

            print("SWAP OPTIONS RAW RESPONSE:")
            print(String(data: data, encoding: .utf8) ?? "nil")

            DispatchQueue.main.async {
                if let decoded = try? JSONDecoder().decode(SwapOptionsResponse.self, from: data) {
                    replacementOptions = decoded.options
                    if decoded.options.isEmpty {
                        swapStatusMessage = "No replacement classes were found for that class."
                    }
                } else if let decodedError = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
                    swapStatusMessage = decodedError.error
                } else {
                    swapStatusMessage = "Swap options could not be decoded."
                }
                isLoadingSwapOptions = false
            }
        }
        .resume()
    }

    func applySelectedSwap() {
        guard !selectedCRN.isEmpty else { return }
        guard !selectedReplacementCRN.isEmpty else { return }
        guard let url = URL(string: "http://127.0.0.1:8000/swap") else { return }

        let body: [String: Any] = [
            "schedule": convertCardsToDict(cardHolder),
            "crn": selectedCRN,
            "replacement_crn": selectedReplacementCRN
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        isApplyingSwap = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, _, error in
            if error != nil {
                DispatchQueue.main.async {
                    isApplyingSwap = false
                }
                return
            }

            guard let data else {
                DispatchQueue.main.async {
                    isApplyingSwap = false
                }
                return
            }

            DispatchQueue.main.async {
                if let decoded = try? JSONDecoder().decode(SwapResponse.self, from: data) {
                    cardHolder = decoded.new_schedule
                    usedCRNs.insert(selectedCRN)
                    selectedCRN = ""
                    selectedReplacementCRN = ""
                    replacementOptions = []
                }

                isApplyingSwap = false
            }
        }
        .resume()
    }
}
