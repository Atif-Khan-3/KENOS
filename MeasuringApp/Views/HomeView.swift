import AVFoundation
import SwiftUI
import RealityKit
import SwiftData
import PhotosUI // 1. Added PhotosUI for modern image picking

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedObject.scanDate, order: .reverse) private var scannedObjects: [ScannedObject]
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    @ObservedObject private var prefs = UserPreferencesManager.shared
    @State private var selectedObject: ScannedObject? = nil
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Good Night"
        }
    }
    
    // MARK: - State Variables
    @State private var showCaptureScreen = false
    @State private var showUnsupportedAlert = false
    
    // New State for Profile Editing
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showNameAlert = false
    @State private var newUserName = ""
    @State private var isShowingRuler = false
    // Add to State Variables
    @State private var isSearching = false
    @State private var searchText = ""

    // Computed filtered list
    private var filteredObjects: [ScannedObject] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return scannedObjects
        }
        return scannedObjects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func verifyAndOpenCapture() {
        if #available(iOS 17.0, *) {
            guard ObjectCaptureSession.isSupported else {
                showUnsupportedAlert = true
                return
            }
            
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCaptureScreen = true
                    } else {
                        print("Camera permission was denied.")
                    }
                }
            }
        } else {
            showUnsupportedAlert = true
        }
    }
    
    var body: some View {
        VStack {
            // MARK: - Header
            HStack {
                // 2. PhotosPicker wraps the image to handle gallery selection automatically
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    if let image = prefs.profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                }
                // 3. Process the selected image asynchronously
                .onChange(of: selectedItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                prefs.updateProfileImage(image: uiImage)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("\(greeting)")
                        .fontWeight(.light)
                        .font(.subheadline)
                    
                    // 4. Wrap the name in a Button to trigger the edit alert
                    Button {
                        newUserName = prefs.userName // Pre-fill current name
                        showNameAlert = true
                    } label: {
                        Text("\(prefs.userName)")
                            .font(.headline)
                            .foregroundColor(.primary) // Keeps it looking like standard text
                    }
                }
                .padding()
                
                Spacer()
                
                Button {
                        withAnimation {
                            isSearching.toggle()
                            if !isSearching {
                                searchText = "" // clear when closing
                            }
                        }
                    } label: {
                        Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                            .scaledToFill()
                            .bold()
                            .frame(width: 40, height: 50)
                            .cornerRadius(70)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.customPurple)
                
            }
            .padding(.horizontal)
            .padding(.top)
            
            if isSearching {
                HStack {
                    //Image(systemName: "magnifyingglass")
                        //.foregroundColor(.gray)
                    TextField("Search by name", text: $searchText)
                        .padding()
                        .glassEffect()
                        .frame(maxWidth: .infinity)
                        .padding(.bottom , 50)
                        .tint(.customPurple)
                }
                .padding(10)
                //.background(Color.gray.opacity(0.1))
                //.cornerRadius(10)
                .padding(.horizontal)
                //.transition(.move(edge: .top).combined(with: .opacity))
                .transition(.opacity)
            }
            
            Spacer()
            
            // MARK: - Content Grid & FAB
            ZStack {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredObjects) { object in
                            HomeCard(
                                objectName: object.name,
                                objectValue: "\(String(object.height))x\(String(object.width))",
                                objectPicture: object.thumbnailImage ?? Image(systemName: "rotate.3d.fill")
                            )
                            .onTapGesture {
                                selectedObject = object
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Menu {
                            Button {
                                isShowingRuler = true
                                print("Ruler Mode selected")
                            } label: {
                                Label("Ruler Mode", systemImage: "ruler")
                            }
                            
                            Button {
                                print("Capture Mode selected")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    verifyAndOpenCapture()
                                }
                            } label: {
                                Label("Capture Mode", systemImage: "arkit")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .bold()
                                .scaledToFill()
                                .frame(width: 40, height: 50)
                                .cornerRadius(70)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color.customPurple)
                        .padding(.trailing, 25)
                    }
                    .padding()
                }
            }
        }
        .fullScreenCover(isPresented: $showCaptureScreen) {
            if #available(iOS 17.0, *) {
                ObjectCaptureContainerView()
            } else {
                Text("Object Capture requires iOS 17 or newer.")
                    .padding()
            }
        }.fullScreenCover(isPresented: $isShowingRuler) {
            MeasureViewWrapper()
                .ignoresSafeArea() // Ensures the camera fills the screen
        }
        .fullScreenCover(item: $selectedObject) { object in
            ScannedObjectARView(object: object)
                .ignoresSafeArea()
        }
        .onAppear {
            print("--- Scanned Objects in Database ---")
            for object in scannedObjects {
                print("ID: \(object.id)")
                print("Name: \(object.name)")
                print("Dimensions: \(object.height) x \(object.width)")
            }
        }
        .alert("Feature Not Available", isPresented: $showUnsupportedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Object Capture requires iPhone 12 Pro or newer with iOS 17+.")
        }
        // 5. The Alert for editing the username
        .alert("Update Name", isPresented: $showNameAlert) {
            TextField("Enter your name", text: $newUserName)
            
            Button("Save") {
                let trimmedName = newUserName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty {
                    prefs.userName = trimmedName
                }
            }
            
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
        } message: {
            Text("How would you like to be greeted?")
        }
    }
}
struct MeasureViewWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MeasureViewController {
        return MeasureViewController()
    }
    
    func updateUIViewController(_ uiViewController: MeasureViewController, context: Context) {
        // Leave empty — no updates needed from SwiftUI to UIKit for now
    }
}
