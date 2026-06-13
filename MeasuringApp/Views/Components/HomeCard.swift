//
//  HomeCard.swift
//  MeasuringApp
//
//  Created by Hussnain on 6/6/26.
//

import SwiftUI

struct HomeCard: View {
    let objectName: String
    let objectValue: String
    let objectPicture: Image
    var body: some View {
        ZStack(alignment: .leading){
            VStack(alignment: .leading){
                Text("\(objectName)")
                    .font(.headline)
                    .bold()
                    .lineLimit(2)
                Text("\(objectValue)")
                    .font(.subheadline)
                Spacer()
                HStack{
                    Spacer()
                    objectPicture
                        .resizable()
                        .scaledToFill()          // 2. Keeps the aspect ratio correct
                        .frame(width: 120, height: 120) // 3. Constrains it to a specific size
                        .padding(.trailing, -40)
                        .padding(.bottom, -40)
                    
                }
            }
            .frame(maxWidth: 200)
            VStack(alignment: .leading){
                Spacer()
                Image(systemName: "arkit")
                    .font(.custom("", size: 30))
                    .frame(width: 50, height: 50)
                    .background(Color.customPurple)
                    .cornerRadius(15)
                    .foregroundStyle(Color.white)
                
            }
            //.padding()
        }
        .padding(20)
        .background(Color.customPurple.opacity(0.3))
        .cornerRadius(20)
        .frame(height: 250)
        .frame(maxWidth: 200)
        
    }
}

#Preview {
    HomeCard(objectName: "Drawing Room Table", objectValue: "5 x 5 ft", objectPicture: Image(systemName: "person"))
}
