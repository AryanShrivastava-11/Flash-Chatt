//
//  CreateNewMessageView.swift
//  Flash Chatt
//
//  Created by Aryan Shrivastava on 14/01/22.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import SDWebImageSwiftUI

class CreateNewMessageViewModel: ObservableObject{
    
    @Published var users: [ChatUser] = []
    @Published var errorMessage = ""
    
    init(){
        fetchAllUsers()
    }
    
    private func fetchAllUsers(){
        Firestore.firestore().collection("users").getDocuments {  documentsSnapshot, error in
            if let err = error{
                self.errorMessage = "Failed to fetch all users: \(err.localizedDescription)"
                print("Error while fetching all users: \(err.localizedDescription)")
                return
            }
            self.errorMessage = "Fetched Users successfully"
            
            documentsSnapshot?.documents.forEach({ snapshot in
                let data = snapshot.data()
                let chatUser = ChatUser(data: data)
                if chatUser.uid != Auth.auth().currentUser?.uid {
                    self.users.append(.init(data: data))
                }

            })
        }
    }
}

struct CreateNewMessageView: View {
    
    let didSelectNewUser: (ChatUser) -> ()
    
    @Environment(\.dismiss) var presentationMode
    
    @ObservedObject var vm = CreateNewMessageViewModel()
    
    var body: some View {
        NavigationView{
            ScrollView{
//                Text("\(vm.errorMessage)")
                ForEach(vm.users){ user in
                    
                    Button {
                        didSelectNewUser(user)
                        presentationMode.callAsFunction()
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: user.profileImageURL))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipped()
                                .cornerRadius(50)
                                .overlay(
                                Circle()
                                    .stroke(lineWidth: 2)
                                    .foregroundColor(.primary)
                                )
                            Text("\(user.email)")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    Divider()
                    .padding(.vertical,8)
                }
                .padding(.top)
            }
            .navigationTitle("New Users")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.callAsFunction()
                    } label: {
                        Text("Cancel")
                    }

                }
            }
        }
    }
}

struct CreateNewMessageView_Previews: PreviewProvider {
    static var previews: some View {
//        MainMessagesView()
        CreateNewMessageView(didSelectNewUser: { user in  })
//            .preferredColorScheme(.dark)
    }
}
