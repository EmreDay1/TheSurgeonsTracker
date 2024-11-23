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
                ProgressView("Yükleniyor...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
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
        ZStack {
            Color.navy.ignoresSafeArea(edges: .all)
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
                TextField("E-posta", text: $email).modifier(CustomTextFieldStyle())
                SecureField("Şifre", text: $password).modifier(CustomTextFieldStyle())
                Button("Giriş Yap") {
                    login()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                Button("Kayıt Ol") {
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
                    Text("Giriş başarısız: \(loginErrorMessage)").foregroundColor(.red).padding()
                }
                Spacer()
            }
        }
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
        ZStack {
            Color.navy.ignoresSafeArea(edges: .all)
            VStack {
                Text("PillTracker1 - Kayıt Ol")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                TextField("E-posta", text: $email).modifier(CustomTextFieldStyle())
                SecureField("Şifre", text: $password).modifier(CustomTextFieldStyle())
                Button("Kayıt Ol") {
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
                    Text("Kayıt başarısız: \(signUpErrorMessage)").foregroundColor(.red).padding()
                }
                Spacer()
            }
        }
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
            VStack {
                List {
                    ForEach(selectedPills) { pill in
                        Section(header: Text(pill.name).foregroundColor(.white)) {
                            ForEach(pill.times, id: \.self) { time in
                                HStack {
                                    Text("\(pill.name) saat \(time, formatter: DateFormatter.timeFormatter)")
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
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.navy)
                .scrollContentBackground(.hidden)

                Spacer()
                
                Button("Bildirim İzinleri İste") {
                    requestNotificationPermission()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                Button("Çıkış Yap") {
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
            .navigationTitle("İlaç Seç")
            .navigationBarItems(leading: Button(action: {
                showingAddPillView.toggle()
            }) {
                Image(systemName: "plus").foregroundColor(.white)
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
                logMessage = "\(pill.name) zamanında alındı \(formatter.string(from: now))"
            } else if timeDifference <= -300 {
                logMessage = "\(pill.name) çok erken alındı \(formatter.string(from: now))"
            } else {
                logMessage = "\(pill.name) GEÇ alındı \(formatter.string(from: now))"
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
            VStack {
                TextField("Yeni İlaç Adı", text: $newPillName).modifier(CustomTextFieldStyle()).padding()
                ForEach(newPillTimes.indices, id: \.self) { index in
                    DatePicker("Hatırlatma Zamanı", selection: Binding(
                        get: { newPillTimes[index] },
                        set: { newPillTimes[index] = $0 }
                    ), displayedComponents: .hourAndMinute)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
                Button("Zaman Ekle") {
                    newPillTimes.append(Date())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                Picker("Aralık", selection: $interval) {
                    Text("Her gün").tag(1)
                    Text("Her 2 günde bir").tag(2)
                    Text("Her 3 günde bir").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .background(Color.gray.opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                Button("İlaç Ekle") {
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
            .navigationTitle("Yeni İlaç Ekle")
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
            scheduleNotification(for: pill.name, date: notificationTime)
        }
    }

    func scheduleNotification(for pillName: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "\(pillName) Hatırlatıcısı"
        content.body = "\(pillName) ilacını almanız gerekiyor."
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
            VStack(spacing: 20) {
                Picker("Ara", selection: $searchByEmail) {
                    Text("E-posta").tag(true)
                    Text("UID").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 20)
                TextField(searchByEmail ? "Kullanıcı e-postasını girin" : "Kullanıcı ID'si (UID) girin", text: $searchInput)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                Button("Kullanıcı Ara") {
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
                    Text(errorMessage).foregroundColor(.red).padding(.horizontal, 20)
                }
                Spacer()
                Button("Çıkış Yap") {
                    logout()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 20)
            }
            .navigationTitle("Admin Paneli")
        }
    }

    func searchUserByEmail() {
        db.collection("users").whereField("email", isEqualTo: searchInput).getDocuments { (querySnapshot, error) in
            if let document = querySnapshot?.documents.first {
                self.userId = document.documentID
                fetchPillLogs()
            } else {
                self.errorMessage = "Bu e-posta ile kullanıcı bulunamadı."
            }
        }
    }

    func fetchPillLogs() {
        guard let userId = userId else {
            self.errorMessage = "Kullanıcı ID'si bulunamadı."
            return
        }
        db.collection("user").document(userId).collection("pill_logs").getDocuments { (snapshot, error) in
            self.pillLogs = snapshot?.documents.compactMap { $0.data()["log"] as? String } ?? []
            if self.pillLogs.isEmpty {
                self.errorMessage = "Bu kullanıcı için ilaç kaydı bulunamadı."
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
