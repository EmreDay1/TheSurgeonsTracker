import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

// Define the Pill structure
struct Pill: Identifiable, Hashable {
    let id: UUID
    var name: String
    var times: [Date]
    var interval: Int // Number of days between reminders
    var taken: Bool = false

    init(id: UUID = UUID(), name: String, times: [Date], interval: Int, taken: Bool = false) {
        self.id = id
        self.name = name
        self.times = times
        self.interval = interval
        self.taken = taken
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let name = data["name"] as? String,
              let times = data["times"] as? [Timestamp],
              let interval = data["interval"] as? Int,
              let taken = data["taken"] as? Bool else {
            return nil
        }
        self.id = UUID(uuidString: document.documentID) ?? UUID()
        self.name = name
        self.times = times.map { $0.dateValue() }
        self.interval = interval
        self.taken = taken
    }

    var dictionary: [String: Any] {
        return [
            "name": name,
            "times": times.map { Timestamp(date: $0) },
            "interval": interval,
            "taken": taken
        ]
    }
}

// ContentView to handle authentication
struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isAdmin = false

    var body: some View {
        if isAuthenticated {
            if isAdmin {
                AdminView(isAuthenticated: $isAuthenticated)
            } else {
                PillSelectionView(isAuthenticated: $isAuthenticated)
            }
        } else {
            LoginView(isAuthenticated: $isAuthenticated, isAdmin: $isAdmin)
        }
    }
}

// Login View
struct LoginView: View {
    @State var email: String = ""
    @State private var password: String = ""
    @State private var loginFailed = false
    @State private var loginErrorMessage = ""
    @Binding var isAuthenticated: Bool
    @Binding var isAdmin: Bool
    @State private var showingSignUp = false

    var body: some View {
        ZStack {
            Color.navy
                .ignoresSafeArea(edges: .all)

            VStack {
                Image("m")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .padding(.top, 50)

                Text("İlaç Uyum Uygulaması")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)

                TextField("Email", text: $email)
                    .modifier(CustomTextFieldStyle())

                SecureField("Password", text: $password)
                    .modifier(CustomTextFieldStyle())

                Button("Login") {
                    login()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Button("Sign Up") {
                    showingSignUp.toggle()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                if loginFailed {
                    Text("Login failed: \(loginErrorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showingSignUp) {
            SignUpView(isAuthenticated: $isAuthenticated)
        }
    }

    func login() {
        print("Attempting to log in with email: \(email) and password: \(password)")

        if email == "admin@gmail.com" {
            print("Admin login successful")
            isAdmin = true
            isAuthenticated = true
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    print("Login failed with error: \(error.localizedDescription)")
                    loginFailed = true
                    loginErrorMessage = error.localizedDescription
                } else {
                    print("Login successful")
                    isAdmin = false
                    isAuthenticated = true
                }
            }
        }
    }
}

// Sign Up View
struct SignUpView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var signUpFailed = false
    @State private var signUpErrorMessage = ""
    @Binding var isAuthenticated: Bool
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.navy
                .ignoresSafeArea(edges: .all)

            VStack {
                Text("PillTracker1 - Sign Up")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)

                TextField("Email", text: $email)
                    .modifier(CustomTextFieldStyle())

                SecureField("Password", text: $password)
                    .modifier(CustomTextFieldStyle())

                Button("Sign Up") {
                    signUp()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                if signUpFailed {
                    Text("Sign Up failed: \(signUpErrorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()
            }
        }
    }

    func signUp() {
        print("Attempting to sign up with email: \(email) and password: \(password)")

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Sign Up failed with error: \(error.localizedDescription)")
                signUpFailed = true
                signUpErrorMessage = error.localizedDescription
            } else {
                print("Sign Up successful")
                isAuthenticated = true

                // Store user info in Firestore
                if let user = authResult?.user {
                    let db = Firestore.firestore()
                    db.collection("users").document(user.uid).setData([
                        "email": user.email ?? "",
                        "userId": user.uid
                    ]) { error in
                        if let error = error {
                            print("Error storing user info in Firestore: \(error)")
                        } else {
                            print("User info successfully stored in Firestore")
                        }
                    }
                }

                // Dismiss sign-up view and show login view
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}



// Pill Selection View
struct PillSelectionView: View {
    @Binding var isAuthenticated: Bool
    @State private var selectedPills: [Pill] = []
    @State private var showingAddPillView = false
    private let db = Firestore.firestore()
    @State private var userId: String?

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(selectedPills) { pill in
                        Section(header: Text(pill.name).foregroundColor(.white)) {
                            ForEach(pill.times, id: \.self) { time in
                                HStack {
                                    Text("\(pill.name) at \(time, formatter: DateFormatter.timeFormatter)")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Toggle(isOn: Binding(
                                        get: { pill.taken },
                                        set: { value in
                                            if let index = selectedPills.firstIndex(where: { $0.id == pill.id }) {
                                                selectedPills[index].taken = value
                                                savePill(pill: selectedPills[index], scheduledTime: time)
                                            }
                                        }
                                    )) {
                                        EmptyView()
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .white))
                                }
                                .padding()
                                .background(Color.navy.opacity(0.8))
                                .cornerRadius(8)
                            }
                        }
                        .listRowBackground(Color.navy)
                        .swipeActions {
                            Button(role: .destructive) {
                                deletePill(pill: pill)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.navy) // Set background color for List
                .scrollContentBackground(.hidden) // Use this modifier to hide the default white background

                Spacer()
                
                Button("Request Notification Permissions") {
                    requestNotificationPermission()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                Button("Logout") {
                    logout()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .navigationTitle("Select Pills")
            .navigationBarItems(leading: Button(action: {
                showingAddPillView.toggle()
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.white)
            })
            .background(Color.navy.ignoresSafeArea())
            .sheet(isPresented: $showingAddPillView) {
                AddPillView(selectedPills: $selectedPills, userId: $userId)
            }
        }
        .background(Color.navy.ignoresSafeArea())
        .onAppear {
            if let user = Auth.auth().currentUser {
                userId = user.uid
                loadPills()
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted.")
            } else if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            } else {
                print("Notification permissions denied.")
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
    }
    
    func loadPills() {
        guard let userId = userId else { return }
        db.collection("user").document(userId).collection("pills").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting documents: \(error)")
            } else {
                if let snapshot = snapshot {
                    self.selectedPills = snapshot.documents.compactMap { Pill(document: $0) }
                }
            }
        }
    }

    func savePill(pill: Pill, scheduledTime: Date) {
        guard let userId = userId else { return }
        let db = Firestore.firestore()
        
        if pill.taken {
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            let timeDifference = now.timeIntervalSince(scheduledTime)
            let logMessage: String
            
            if timeDifference > -300 && timeDifference < 900 { // within -5 to +15 minutes
                logMessage = "Pill \(pill.name) taken timely at \(formatter.string(from: now))"
            } else if timeDifference <= -300 { // more than 5 minutes early
                logMessage = "Pill \(pill.name) taken too early at \(formatter.string(from: now))"
            } else { // 15 minutes or more late
                logMessage = "Pill \(pill.name) taken LATE at \(formatter.string(from: now))"
            }
            
            db.collection("user").document(userId).collection("pill_logs").addDocument(data: ["log": logMessage]) { error in
                if let error = error {
                    print("Error logging pill: \(error)")
                } else {
                    print("Pill log successfully added!")
                }
            }
        }
        
        db.collection("user").document(userId).collection("pills").document(pill.id.uuidString).setData(pill.dictionary) { error in
            if let error = error {
                print("Error saving pill: \(error)")
            } else {
                print("Pill successfully saved!")
            }
        }
    }
    
    func deletePill(pill: Pill) {
        guard let userId = userId else { return }
        db.collection("user").document(userId).collection("pills").document(pill.id.uuidString).delete { error in
            if let error = error {
                print("Error deleting pill: \(error)")
            } else {
                if let index = selectedPills.firstIndex(of: pill) {
                    selectedPills.remove(at: index)
                }
                print("Pill successfully deleted!")
            }
        }
    }
}

// Add Pill View
struct AddPillView: View {
    @Binding var selectedPills: [Pill]
    @Environment(\.presentationMode) var presentationMode
    @State private var newPillName: String = ""
    @State private var newPillTimes: [Date] = []
    @State private var interval: Int = 1
    @Binding var userId: String?

    var body: some View {
        NavigationView {
            VStack {
                TextField("New Pill Name", text: $newPillName)
                    .modifier(CustomTextFieldStyle())
                    .padding()

                ForEach(newPillTimes.indices, id: \.self) { index in
                    DatePicker("Reminder Time", selection: Binding(
                        get: { newPillTimes[index] },
                        set: { newPillTimes[index] = $0 }
                    ), displayedComponents: .hourAndMinute)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }

                Button("Add Time") {
                    newPillTimes.append(Date())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Picker("Interval", selection: $interval) {
                    Text("Every day").tag(1)
                    Text("Every 2 days").tag(2)
                    Text("Every 3 days").tag(3)
                    // Add more options as needed
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color.gray.opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Button("Add Pill") {
                    addPill()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()
            }
            .navigationTitle("Add New Pill")
            .background(Color.navy.ignoresSafeArea())
        }
    }

    func addPill() {
        if !newPillName.isEmpty && !newPillTimes.isEmpty {
            let newPill = Pill(name: newPillName, times: newPillTimes, interval: interval)
            selectedPills.append(newPill)
            scheduleNotifications(for: newPill)
            savePill(pill: newPill)
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    func scheduleNotifications(for pill: Pill) {
        for time in pill.times {
            let notificationTime = time
            scheduleNotification(date: notificationTime)
            print("Notification time set: \(notificationTime)")
        }
    }

    func scheduleNotification(date: Date) {
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = "Pill Reminder"
        content.body = "Time to take your pill."
        content.sound = .default

        // Extract hour and minute components from the time of day
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Create a trigger to fire the notification at the specified time of day
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create the request
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled to repeat every day at \(hour):\(minute)")
            }
        }
    }

    func savePill(pill: Pill) {
        guard let userId = userId else { return }
        let db = Firestore.firestore()
        db.collection("user").document(userId).collection("pills").document(pill.id.uuidString).setData(pill.dictionary) { error in
            if let error = error {
                print("Error saving pill: \(error)")
            } else {
                print("Pill successfully saved!")
            }
        }
    }
}



struct AdminView: View {
    @Binding var isAuthenticated: Bool
    @State private var searchInput: String = ""
    @State private var searchByEmail: Bool = true
    @State private var userId: String? = nil
    @State private var pillLogs: [String] = []
    @State private var errorMessage: String = ""
    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Picker("Search by", selection: $searchByEmail) {
                    Text("Email").tag(true)
                    Text("UID").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 20)

                TextField(searchByEmail ? "Enter user email" : "Enter User ID (UID)", text: $searchInput)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)

                Button("Search User") {
                    errorMessage = ""
                    pillLogs = []
                    if searchByEmail {
                        searchUserByEmail()
                    } else {
                        userId = searchInput
                        fetchPillLogs()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)

                if !pillLogs.isEmpty {
                    List(pillLogs, id: \.self) { log in
                        Text(log)
                    }
                    .listStyle(PlainListStyle())
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }

                Spacer()

                Button("Logout") {
                    logout()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
            }
            .navigationTitle("Admin Panel")
        }
    }

    func searchUserByEmail() {
        db.collection("users").whereField("email", isEqualTo: searchInput).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
                self.errorMessage = "Error fetching user: \(error.localizedDescription)"
                return
            }

            if let document = querySnapshot?.documents.first {
                self.userId = document.documentID
                print("User found with ID: \(self.userId ?? "No userId")")
                fetchPillLogs()
            } else {
                self.errorMessage = "No user found with this email."
            }
        }
    }

    func fetchPillLogs() {
        guard let userId = userId else {
            self.errorMessage = "User ID not found."
            return
        }

        db.collection("user").document(userId).collection("pill_logs").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching pill logs: \(error.localizedDescription)")
                self.errorMessage = "Failed to fetch pill logs: \(error.localizedDescription)"
                return
            }

            print("Fetched \(snapshot?.documents.count ?? 0) pill logs.")
            self.pillLogs = snapshot?.documents.compactMap { $0.data()["log"] as? String } ?? []
            if self.pillLogs.isEmpty {
                self.errorMessage = "No pill logs found for this user."
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
    }
}
struct CustomTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.gray.opacity(0.5))
            .cornerRadius(5)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
    }
}

extension Color {
    static let navy = Color(red: 0.0, green: 0.0, blue: 0.5)
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}



// Preview Providers
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct LoginView_Previews: PreviewProvider {
    @State static var isAuthenticated = false
    @State static var isAdmin = false

    static var previews: some View {
        LoginView(isAuthenticated: $isAuthenticated, isAdmin: $isAdmin)
    }
}

struct SignUpView_Previews: PreviewProvider {
    @State static var isAuthenticated = false
    
    static var previews: some View {
        SignUpView(isAuthenticated: $isAuthenticated)
    }
}

struct PillSelectionView_Previews: PreviewProvider {
    @State static var isAuthenticated = true
    
    static var previews: some View {
        PillSelectionView(isAuthenticated: $isAuthenticated)
    }
}

struct AddPillView_Previews: PreviewProvider {
    @State static var selectedPills: [Pill] = []
    @State static var userId: String? = nil
    
    static var previews: some View {
        AddPillView(selectedPills: $selectedPills, userId: $userId)
    }
}

struct AdminView_Previews: PreviewProvider {
    @State static var isAuthenticated = true
    
    static var previews: some View {
        AdminView(isAuthenticated: $isAuthenticated)
    }
}
