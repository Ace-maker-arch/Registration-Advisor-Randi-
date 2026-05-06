import SwiftUI

enum HomeTab {
    case nextSemester
    case currentClasses
}

struct HomeView: View {
    @State var selectedCRN = ""
    @State var selectedReplacementCRN = ""
    @State var profile: StudentProfile?
    @State var cardHolder: [Card] = []
    @State var replacementOptions: [Card] = []
    @State var modalityPreference: ModalityPreference?
    @State var isGeneratingResponse = false
    @State var isLoadingSwapOptions = false
    @State var isApplyingSwap = false
    @State var isShowingPDFPicker = false
    @State var selectedPDFURL: URL?
    @State var usedCRNs: Set<String> = []
    @State var selectedTab: HomeTab = .nextSemester
    @State var currentCourses: [Card] = []
    @State var studentName: String?
    @State var isLoadingSchedule = false
    @State var isShowingSchedulePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.blue.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("REGI")
                            .padding()
                            .foregroundColor(.red)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Upload your Degree Works PDF to get class recommendations")
                            .frame(width: 300)
                            .foregroundColor(.red)
                            .fontWeight(.bold)

                        if let profile {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Major: \(profile.major ?? "N/A")")
                                Text("GPA: \(profile.gpa ?? "N/A")")
                                Text("Credits Remaining: \(profile.credits_remaining ?? 0)")
                            }
                            .foregroundColor(.white)
                        }

                        HStack(spacing: 0) {
                            Button("Next Semester") {
                                selectedTab = .nextSemester
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == .nextSemester ? Color.white.opacity(0.2) : Color.clear)
                            .foregroundColor(.white)
                            .fontWeight(selectedTab == .nextSemester ? .bold : .regular)

                            Button("Current Classes") {
                                selectedTab = .currentClasses
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedTab == .currentClasses ? Color.white.opacity(0.2) : Color.clear)
                            .foregroundColor(.white)
                            .fontWeight(selectedTab == .currentClasses ? .bold : .regular)
                        }
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(10)

                        if selectedTab == .nextSemester {
                            nextSemesterContent
                        } else {
                            currentClassesContent
                        }

                        Spacer()
                    }
                    .padding()
                    .onAppear {
                        requestNotificationPermission()
                    }
                }
            }
        }
    }
}
