//
//  ProfileCard.swift
//  MeasuringApp
//
//  Created by Atif Khan  on 06/06/2026.
//

import SwiftUI
import PhotosUI

struct ProfileCard: View {
    @State var username:String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    let manager = UserPreferencesManager.shared
    @State var checkProfile:Bool = false
    let isupdate:Bool
    var body: some View {
        VStack(alignment: .leading){
            
            HStack(alignment: .center){
                Spacer()
                VStack(){
                         if let image = selectedImage {
                             Image(uiImage: image)
                                 .resizable()
                                 .scaledToFill()
                                 .frame(width: 150, height: 150)
                                 .cornerRadius(150)
                         }
                     else{
                         Image(systemName:"person.circle.fill")
                             .resizable()
                             .scaledToFit()
                             .frame(height: 150)
                             .foregroundColor(Color.secondary)
                             .cornerRadius(150)
                     }
                        // Spacer()
                         PhotosPicker(
                               selection: $selectedItem,
                               matching: .images
                           ) {
                               Text(isupdate ? "Edit Photo" : "Upload Photo").foregroundColor(Color.white)
                           }
                           .padding()
                           .buttonStyle(.glassProminent)
                           .tint(Color.customPurple)
                            .onChange(of: selectedItem) { _, newItem in
                               Task {
                                   if let data = try? await newItem?.loadTransferable(type: Data.self),
                                      let uiImage = UIImage(data: data) {
                                       selectedImage = uiImage
                                   }
                               }
                           }
                     }
               

                Spacer()
            }.padding(.bottom , 10)

                
            
           
            
            VStack(alignment: .leading){
                
                Text("Name")
                TextField("Enter your name", text: $username)
                    .padding()
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom , 50)
            
                Button {
                    if !username.isEmpty, let selectedImage = selectedImage{
                        manager.userName = username
                        manager.isProfileCreated = true
                        manager.updateProfileImage(image: selectedImage ?? UIImage())
                    }else{
                        checkProfile = true
                    }
                    
                } label: {
                    Text(isupdate ? "Update Profile" : "Create Profile")
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        
                }
                
                .buttonStyle(.glassProminent)
                .tint(Color.customPurple)
            }.padding()
    //        .background(Color.secondary.opacity(0.1))
        }.padding(.horizontal).alert("All Fields required", isPresented: $checkProfile) {
            Button("OK", role: .cancel) { }
        }
        
      // Text("\(manager.userName ?? "No Name")")
    }
}

#Preview {
    ProfileCard(isupdate: false)
}
