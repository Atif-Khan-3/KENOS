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
                    .font(.title3)
                    .bold()
                    .lineLimit(2)
                Text("\(objectValue)")
                    .font(.title3)
                Spacer()
                HStack{
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.ellipsis")
                        .font(.custom("", size: 100))
                        .padding(.trailing, -40)
                        .padding(.bottom, -40)
                    
                }
            }
            .frame(maxWidth: 200)
            VStack(alignment: .leading){
                Spacer()
                Image(systemName: "arkit")
                    .font(.custom("", size: 40))
                    .frame(width: 60, height: 60)
                    .background(Color.customPurple)
                    .cornerRadius(15)
                    .foregroundStyle(Color.white)
                
            }
            //.padding()
        }
        .padding(20)
        .cornerRadius(20)
        .frame(height: 300)
        .frame(maxWidth: 300)
        
    }
}

#Preview {
    HomeCard(objectName: "Drawing Room Table", objectValue: "5 x 5 ft", objectPicture: Image(systemName: "person"))
}
