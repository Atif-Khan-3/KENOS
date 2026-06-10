//
//  HomeView.swift
//  MeasuringApp
//
//  Created by Atif Khan  on 08/06/2026.
//

import SwiftUI
import Foundation
struct HomeView: View {
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
    @State private var showAlert = false

    var body: some View {
        VStack{
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
                        ForEach(items, id: \.name) { item in
                                          HomeCard(
                                              objectName: item.name,
                                              objectValue: item.value,
                                              objectPicture: Image(systemName: "cube.box")
                                          )
                                      }
                    }
                }.padding(.horizontal)
                  
               
                VStack( ){
                    Spacer()
                    HStack{
                        Spacer()
                        Button {
                            showAlert.toggle()
                        } label: {
                            Image(systemName: "plus")
                                .scaledToFill()
                                .frame(width: 50, height: 60)
                                .cornerRadius(70)
                            
                            
                            
                        }.buttonStyle(.glassProminent)
                            .tint(Color.customPurple)
                                .padding(.trailing, 10)
                                .alert("Select a Mode", isPresented: $showAlert) {
                                    Button("Ruler Mode") {
                                            // action when Ruler Mode is tapped
                                            print("Ruler Mode selected")
                                        }
                                        Button("Capture Mode") {
                                            // action when Capture Mode is tapped
                                            print("Capture Mode selected")
                                        }
                                        Button("Cancel", role: .cancel) {
                                            // cancel just dismisses, action optional
                                        }
                                }
                    }.padding()
                }
                
            }
        }
    }
}
#Preview {
    HomeView()
}
