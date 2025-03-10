import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

struct Pill: Identifiable, Hashable {
    let id: UUID
    var name: String
    var times: [Date]
    var interval: Int
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

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isAdmin = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if isAuthenticated {
                if isAdmin {
                    AdminView(isAuthenticated: $isAuthenticated)
                } else {
                    PillSelectionView(isAuthenticated: $isAuthenticated)
                }
            } else {
                LoginView(isAuthenticated: $isAuthenticated, isAdmin: $isAdmin)
            }
        }
        .onAppear {
            checkUserAuthentication()
        }
    }

    private func checkUserAuthentication() {
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                self.isAuthenticated = true
                self.isAdmin = user.email == "admin@example.com"
            } else {
                self.isAuthenticated = false
            }
            self.isLoading = false
        }
    }
}

struct LoginView: View {
    @State var email: String = ""
    @State private var password: String = ""
    @State private var loginFailed = false
    @State private var loginErrorMessage = ""
    @Binding var isAuthenticated: Bool
    @Binding var isAdmin: Bool
    @State private var showingSignUp = false

    var body: some View {
        VStack {
            Text("Medication Tracking App")
                .font(.title)
                .padding(.bottom, 20)
            
            TextField("Email", text: $email)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            SecureField("Password", text: $password)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Login") {
                login()
            }
            .padding()
            
            Button("Sign Up") {
                showingSignUp.toggle()
            }
            .padding()
            
            if loginFailed {
                Text("Login failed: \(loginErrorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $showingSignUp) {
            SignUpView(isAuthenticated: $isAuthenticated)
        }
    }

    func login() {
        if email == "admin@gmail.com" {
            isAdmin = true
            isAuthenticated = true
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    loginFailed = true
                    loginErrorMessage = error.localizedDescription
                } else {
                    isAdmin = false
                    isAuthenticated = true
                }
            }
        }
    }
}

struct SignUpView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var signUpFailed = false
    @State private var signUpErrorMessage = ""
    @Binding var isAuthenticated: Bool
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Sign Up")
                .font(.title)
                .padding(.bottom, 20)
            
            TextField("Email", text: $email)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            SecureField("Password", text: $password)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Sign Up") {
                signUp()
            }
            .padding()
            
            if signUpFailed {
                Text("Sign up failed: \(signUpErrorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }

    func signUp() {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                signUpFailed = true
                signUpErrorMessage = error.localizedDescription
            } else {
                isAuthenticated = true
                if let user = authResult?.user {
                    let db = Firestore.firestore()
                    db.collection("users").document(user.uid).setData([
                        "email": user.email ?? "",
                        "userId": user.uid
                    ])
                }
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct PillSelectionView: View {
    @Binding var isAuthenticated: Bool
    @State private var selectedPills: [Pill] = []
    @State private var showingAddPillView = false
    private let db = Firestore.firestore()
    @State private var userId: String?

    var body: some View {
        NavigationView {
            List {
                ForEach(selectedPills) { pill in
                    Section(header: Text(pill.name)) {
                        ForEach(pill.times, id: \.self) { time in
                            HStack {
                                Text("\(pill.name) at \(time, formatter: DateFormatter.timeFormatter)")
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { pill.taken },
                                    set: { value in
                                        if let index = selectedPills.firstIndex(where: { $0.id == pill.id }) {
                                            selectedPills[index].taken = value
                                            savePill(pill: selectedPills[index], scheduledTime: time)
                                        }
                                    }
                                ))
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            deletePill(pill: pill)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Select Medication")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingAddPillView.toggle()
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Request Notifications") {
                        requestNotificationPermission()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        logout()
                    }
                }
            }
            .sheet(isPresented: $showingAddPillView) {
                AddPillView(selectedPills: $selectedPills, userId: $userId)
            }
        }
        .onAppear {
            if let user = Auth.auth().currentUser {
                userId = user.uid
                loadPills()
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch {}
    }
    
    func loadPills() {
        guard let userId = userId else { return }
        db.collection("user").document(userId).collection("pills").getDocuments { snapshot, error in
            if let snapshot = snapshot {
                self.selectedPills = snapshot.documents.compactMap { Pill(document: $0) }
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
            
            if timeDifference > -300 && timeDifference < 900 {
                logMessage = "\(pill.name) taken on time \(formatter.string(from: now))"
            } else if timeDifference <= -300 {
                logMessage = "\(pill.name) taken too early \(formatter.string(from: now))"
            } else {
                logMessage = "\(pill.name) taken LATE \(formatter.string(from: now))"
            }
            
            db.collection("user").document(userId).collection("pill_logs").addDocument(data: ["log": logMessage])
        }
        
        db.collection("user").document(userId).collection("pills").document(pill.id.uuidString).setData(pill.dictionary)
    }
    
    func deletePill(pill: Pill) {
        guard let userId = userId else { return }
        db.collection("user").document(userId).collection("pills").document(pill.id.uuidString).delete()
        if let index = selectedPills.firstIndex(of: pill) {
            selectedPills.remove(at: index)
        }
    }
}

struct AddPillView: View {
    @Binding var selectedPills: [Pill]
    @Environment(\.presentationMode) var presentationMode
    @State private var newPillName: String = ""
    @State private var newPillTimes: [Date] = []
    @State private var interval: Int = 1
    @Binding var userId: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medication Information")) {
                    TextField("New Medication Name", text: $newPillName)
                
                    ForEach(newPillTimes.indices, id: \.self) { index in
                        DatePicker("Reminder Time", selection: Binding(
                            get: { newPillTimes[index] },
                            set: { newPillTimes[index] = $0 }
                        ), displayedComponents: .hourAndMinute)
                    }
                
                    Button("Add Time") {
                        newPillTimes.append(Date())
                    }
                }
                
                Section(header: Text("Interval")) {
                    Picker("Interval", selection: $interval) {
                        Text("Every day").tag(1)
                        Text("Every 2 days").tag(2)
                        Text("Every 3 days").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Button("Add Medication") {
                        addPill()
                    }
                }
            }
            .navigationTitle("Add New Medication")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
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
            scheduleNotification(for: pill.name, date: notificationTime)
        }
    }

    func scheduleNotification(for pillName: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "\(pillName) Reminder"
        content.body = "You need to take your \(pillName) medication."
        content.sound = .default

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }

    func savePill(pill: Pill) {
        guard let userId = userId else { return }
        let db = Firestore.firestore()
        db.collection("user").document(userId).collection("pills").document(pill.id.uuidString).setData(pill.dictionary)
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
            VStack {
                Picker("Search by", selection: $searchByEmail) {
                    Text("Email").tag(true)
                    Text("UID").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TextField(searchByEmail ? "Enter user email" : "Enter user ID (UID)", text: $searchInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
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
                .padding()
                
                if !pillLogs.isEmpty {
                    List(pillLogs, id: \.self) { log in
                        Text(log)
                    }
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
                
                Button("Logout") {
                    logout()
                }
                .padding()
            }
            .navigationTitle("Admin Panel")
            .padding()
        }
    }

    func searchUserByEmail() {
        db.collection("users").whereField("email", isEqualTo: searchInput).getDocuments { (querySnapshot, error) in
            if let document = querySnapshot?.documents.first {
                self.userId = document.documentID
                fetchPillLogs()
            } else {
                self.errorMessage = "User with this email not found."
            }
        }
    }

    func fetchPillLogs() {
        guard let userId = userId else {
            self.errorMessage = "User ID not found."
            return
        }
        db.collection("user").document(userId).collection("pill_logs").getDocuments { (snapshot, error) in
            self.pillLogs = snapshot?.documents.compactMap { $0.data()["log"] as? String } ?? []
            if self.pillLogs.isEmpty {
                self.errorMessage = "No medication logs found for this user."
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch {}
    }
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
