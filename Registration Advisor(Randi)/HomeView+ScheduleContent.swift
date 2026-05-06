import SwiftUI
import UniformTypeIdentifiers

extension HomeView {
    var filteredCards: [Card] {
        switch modalityPreference {
        case .wpOnlineOnly?:
            return cardHolder.filter {
                $0.section.modality == "ONLINE_ASYNC" || $0.section.modality == "ONLINE_SYNC"
            }
        case .inPersonWithAsync?:
            return cardHolder.filter {
                $0.section.modality == "IN_PERSON" || $0.section.modality == "ONLINE_ASYNC"
            }
        case nil:
            return cardHolder
        }
    }

    var nextSemesterContent: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)

                if let selectedPDFURL {
                    Text("Selected PDF: \(selectedPDFURL.lastPathComponent)")
                        .foregroundColor(.white)
                } else {
                    Text("No PDF selected yet.")
                        .foregroundColor(.gray)
                }
            }

            Button("Import PDF") {
                isShowingPDFPicker = true
            }
            .fileImporter(isPresented: $isShowingPDFPicker, allowedContentTypes: [.pdf]) { result in
                switch result {
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

            if isGeneratingResponse {
                Text("AI generating response...")
                    .foregroundColor(.yellow)
                    .fontWeight(.semibold)
            }

            if selectedPDFURL != nil {
                VStack(spacing: 12) {
                    Text("Choose Class Type Before Generating")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)

                    HStack {
                        Button("WP Online") {
                            modalityPreference = .wpOnlineOnly
                            uploadPDF()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(10)

                        Button("In Person + Async") {
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

            if filteredCards.isEmpty {
                Text("No recommendations yet")
                    .foregroundColor(.red)
            } else {
                ForEach(filteredCards, id: \.crn) { card in
                    VStack {
                        RecommendationCardView(card: card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedCRN == card.crn ? Color.green : Color.clear, lineWidth: 3)
                            )

                        Button("Select This Class") {
                            selectedCRN = card.crn
                            replacementOptions = []
                            selectedReplacementCRN = ""
                            swapStatusMessage = nil
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

                Button("Show Swap Options") {
                    loadSwapOptions()
                }
                .disabled(selectedCRN.isEmpty || isLoadingSwapOptions)
                .opacity(selectedCRN.isEmpty || isLoadingSwapOptions ? 0.5 : 1.0)
                .padding()
                .foregroundColor(.white)
                .background(Color.purple)
                .cornerRadius(10)

                if isLoadingSwapOptions {
                    Text("Loading replacement classes...")
                        .foregroundColor(.yellow)
                }

                if let swapStatusMessage {
                    Text(swapStatusMessage)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                if !replacementOptions.isEmpty {
                    Text("Choose a replacement class")
                        .foregroundColor(.white)
                        .fontWeight(.bold)

                    ForEach(replacementOptions, id: \.crn) { replacement in
                        VStack {
                            RecommendationCardView(card: replacement)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedReplacementCRN == replacement.crn ? Color.orange : Color.clear, lineWidth: 3)
                                )

                            Button("Swap In This Class") {
                                selectedReplacementCRN = replacement.crn
                            }
                            .foregroundColor(.white)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }
                    }
                }

                if !selectedReplacementCRN.isEmpty {
                    Text("Replacement Selected: \(selectedReplacementCRN)")
                        .foregroundColor(.orange)
                }

                Button("Confirm Swap") {
                    applySelectedSwap()
                }
                .disabled(selectedCRN.isEmpty || selectedReplacementCRN.isEmpty || isApplyingSwap)
                .opacity(selectedCRN.isEmpty || selectedReplacementCRN.isEmpty || isApplyingSwap ? 0.5 : 1.0)
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)

                if isApplyingSwap {
                    Text("Applying selected swap...")
                        .foregroundColor(.yellow)
                }

                Button("Confirm Recommended Classes") {
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

    var currentClassesContent: some View {
        VStack(spacing: 20) {
            Text("Current Semester Classes")
                .foregroundColor(.green)
                .fontWeight(.bold)

            Text("Import your Banner schedule PDF to see your exact current classes")
                .frame(width: 300)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Button("Import Schedule PDF") {
                isShowingSchedulePicker = true
            }
            .fileImporter(isPresented: $isShowingSchedulePicker, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result {
                    uploadSchedulePDF(url)
                }
            }
            .foregroundColor(.black)
            .background(Color.orange.opacity(0.9))
            .cornerRadius(10)
            .frame(width: 200)

            if isLoadingSchedule {
                Text("Loading your schedule...")
                    .foregroundColor(.yellow)
                    .fontWeight(.semibold)
            }

            if currentCourses.isEmpty && !isLoadingSchedule {
                Text("No schedule loaded yet")
                    .foregroundColor(.red)
            } else {
                ForEach(currentCourses, id: \.crn) { card in
                    RecommendationCardView(card: card)
                }
            }
        }
    }
}
