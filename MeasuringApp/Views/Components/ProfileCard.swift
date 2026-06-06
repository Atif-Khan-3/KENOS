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
                               Text("Select Image").foregroundColor(Color.white)
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
                    //Todo
                } label: {
                    Text(isupdate ? "Update Profile" : "Create Profile")
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        
                }
                
                .buttonStyle(.glassProminent)
                .tint(Color.customPurple)
            }.padding()
    //        .background(Color.secondary.opacity(0.1))
        }.padding(.horizontal)
        
       
    }
}

#Preview {
    ProfileCard(isupdate: true)
}
