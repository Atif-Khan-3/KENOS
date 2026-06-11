//
//  HomeView.swift
//  MeasuringApp
//
//  Created by Atif Khan  on 08/06/2026.
//
import AVFoundation
import SwiftUI
import Foundation
import _RealityKit_SwiftUI
import RealityKit
import SwiftData
struct HomeView: View {
    @Query(sort: \ScannedObject.scanDate, order: .reverse) private var scannedObjects: [ScannedObject]
        @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScannedObject.scanDate, order: .reverse) private var savedScans: [ScannedObject]
    let items = [
        (name: "Drawing Room Table", value: "5 x 5 ft"),
        (name: "Office Chair",       value: "3 x 3 ft"),
        (name: "Bookshelf",          value: "6 x 2 ft"),
        (name: "Coffee Table",       value: "4 x 2 ft"),
        (name: "TV Stand",           value: "5 x 1.5 ft"),
        (name: "Wardrobe",           value: "7 x 3 ft"),
    ]
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    @ObservedObject private var prefs = UserPreferencesManager.shared
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Good Night"
        }
    }
    @State private var showCaptureScreen = false
    @State private var showUnsupportedAlert = false
    private func verifyAndOpenCapture() {
        if #available(iOS 17.0, *) {
            // 1. Check if hardware is supported
            guard ObjectCaptureSession.isSupported else {
                showUnsupportedAlert = true
                return
            }
            
            // 2. Force iOS to check/request Camera permissions
            AVCaptureDevice.requestAccess(for: .video) { granted in
                // UI updates must happen on the main thread
                DispatchQueue.main.async {
                    if granted {
                        // Permission is granted, safe to open the AR view
                        showCaptureScreen = true
                    } else {
                        // The user denied it, or iOS blocked it.
                        print("Camera permission was denied.")
                        // Optional: You could trigger another alert here telling the user
                        // to open the iOS Settings app to enable camera access.
                    }
                }
            }
        } else {
            showUnsupportedAlert = true
        }
    }
    var body: some View {
        VStack{
//            Color(UIColor.systemBackground)
//                .ignoresSafeArea()
//                .fullScreenCover(isPresented: $showCaptureScreen) {
//                    if #available(iOS 17.0, *) {
//                        ObjectCaptureContainerView()
//                    } else {
//                        Text("Object Capture requires iOS 17 or newer.")
//                    }
//                }
            HStack{
                if let image = prefs.profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                } else {
                    // Placeholder
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                VStack(alignment: .leading){
                    Text("\(greeting)")
                        .fontWeight(.light)
                    Text("\(prefs.userName)")
                    
                }.padding()
                Spacer()
                Button {
                    //todo
                } label: {
                    Image(systemName: "magnifyingglass")
                        .scaledToFill()
                        .frame(width: 40, height: 50)
                        .cornerRadius(70)
                    
                    
                    
                }.buttonStyle(.glassProminent)
                    .tint(Color.customPurple)
                
                
                
                
            }.padding(.horizontal)
                .padding(.top)
            Spacer()
            ZStack{
                ScrollView(showsIndicators: false){
                    LazyVGrid(columns: columns, spacing: 16){
                        ForEach(scannedObjects) { object in
                            HomeCard(
                                objectName: object.name,
                                objectValue: String(object.height), // Using the computed property from before
                                objectPicture: object.thumbnailImage ?? Image(systemName: "cube.box")
                            )
                            
                        }
                    }
                }.padding(.horizontal)
//                
//                List(savedScans) { scan in
//                                VStack(alignment: .leading) {
//                                    Text(scan.name)
//                                        .font(.headline)
//                                    Text("Scanned on: \(scan.scanDate.formatted(date: .abbreviated, time: .shortened))")
//                                        .font(.caption)
//                                        .foregroundColor(.gray)
//                                    Text(String(scan.height*3.28084))
//                                    Text(String(scan.width*3.28084))
//                                    
//                                }
//                            }
//                            .navigationTitle("My 3D Models")
               
                VStack( ){
                    Spacer()
                    HStack{
                        Spacer()
                        Menu {
                            Button {
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
                            
                            // Destructive/Cancel actions can also be added if needed
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
                    }.padding()
                }
                
            }
        }.fullScreenCover(isPresented: $showCaptureScreen) {
            if #available(iOS 17.0, *) {
                ObjectCaptureContainerView()          } else {
                Text("Object Capture requires iOS 17 or newer.")
                    .padding()
            }
        }
        .onAppear {
            // 4. Print all values when the view appears
            print("--- Scanned Objects in Database ---")
            for object in scannedObjects {
                print("ID: \(object.id)")
                print("Name: \(object.name)")
                print("Dimensions: \(object.height) x \(object.width)")
                print("Date: \(object.scanDate)")
                print("Path: \(object.modelFilePath ?? "None")")
               // print("Thumbnail: \(object.thumbnailData ?? "None")")
                print("-----------------------------------")
            }
        }
        // ✅ REMOVED the .onAppear { verifyAndOpenCapture() } — this was the black screen cause
        .alert("Feature Not Available", isPresented: $showUnsupportedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Object Capture requires iPhone 12 Pro or newer with iOS 17+.")
        }
    }
}
//#Preview {
//    HomeView()
//}
