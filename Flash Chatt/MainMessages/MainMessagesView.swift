//
//  MainMessagesView.swift
//  Flash Chatt
//
//  Created by Aryan Shrivastava on 26/12/21.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import SDWebImageSwiftUI
import FirebaseFirestoreSwift


class MainMessagesViewModel: ObservableObject{
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var isCurrentlyLoggedOut = false
    
    init(){
        DispatchQueue.main.async {
            self.isCurrentlyLoggedOut = Auth.auth().currentUser?.uid == nil
        }
        fetchCurrentUser()
        
        fetchRecentMessages()
    }
    
    @Published var recentMessages = [RecentMessage]()
    
    private var firestoreListener: ListenerRegistration?
    
    func fetchRecentMessages(){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        firestoreListener?.remove()
        
        //we must remove all the messages otherwise old messages will also be considered
        self.recentMessages.removeAll()
        
        firestoreListener = Firestore.firestore().collection("recent_messages").document(uid).collection("messages").order(by: "timestamp").addSnapshotListener { querySnapshot, error in
            if let err = error {
                self.errorMessage = "Failed to listen for recent messages: \(err.localizedDescription)"
                print(self.errorMessage)
                return
            }
            querySnapshot?.documentChanges.forEach({ change in
                let docId = change.document.documentID
                
                if let index = self.recentMessages.firstIndex(where: { rm in
                    return rm.id == docId
                }) {
                    self.recentMessages.remove(at: index)
                }
//                self.recentMessages.append(.init(documentId: docId, data: change.document.data()))
                
//                self.recentMessages.insert(.init(documentId: docId, data: change.document.data()), at: 0)
                
                do{
                    if let rm = try change.document.data(as: RecentMessage.self){
                        
                        self.recentMessages.insert(rm, at: 0)
                    }
                }catch{
                    print(error)
                }
            })
        }
    }
    
    func fetchCurrentUser(){
        guard let uid =  Auth.auth().currentUser?.uid else {
            errorMessage = "Could not find the uid"
            return
        }
        
        errorMessage = "\(uid)"
        
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            if let err = error{
                print("Failed to fetch the current user:\(err.localizedDescription)")
                return
            }
            guard let data = snapshot?.data() else { return }
            self.chatUser = .init(data: data)
//            self.errorMessage = "\(chatUser.profileImageURL)"
        }
    }
    
    func handleSignOut(){
        isCurrentlyLoggedOut.toggle()
        try? Auth.auth().signOut()
    }
    
}

struct MainMessagesView: View {
    
    @State var shouldShowLogOutOptions = false
    @ObservedObject var vm = MainMessagesViewModel()
    @State var shouldNavigateToChatLogView = false
    
    private var chatLogViewModel = ChatLogViewModel(chatUser: nil, currentUser: nil)
    
    var body: some View {
        NavigationView{
            VStack {
//                Text("USER: \(vm.chatUser?.uid ?? "")")
                
                //custom nav bar
                customNavBar
                
                messagesView
                
                NavigationLink("", isActive: $shouldNavigateToChatLogView) {
//                    ChatLogView(chatUser: chatUser, currentUser: vm.chatUser)
                    ChatLogView(vm: chatLogViewModel)
                }
            }
            .overlay(
                newMessageButton ,alignment: .bottom)
            .navigationBarHidden(true)
//            .navigationTitle("Main Messages View")
        }
    }
    
    private var customNavBar: some View{
        HStack(spacing: 16) {
            
            WebImage(url: URL(string: vm.chatUser?.profileImageURL ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipped()
                .cornerRadius(50)
                .overlay(
                    RoundedRectangle(cornerRadius: 44)
                        .stroke(.primary, lineWidth: 1)
                )
                .shadow(radius: 5)
            
//            Image(systemName: "person.fill")
//                .font(.system(size: 34,weight: .bold))
        
            
            VStack(alignment: .leading, spacing: 4) {
//                let email = vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? ""
                let email = vm.chatUser?.email ?? ""
                let username = vm.chatUser?.email.components(separatedBy: "@").first ?? email
                
                Text(username)
                    .font(.system(size: 24, weight: .bold))
                HStack {
                    Circle()
                        .frame(width: 14, height: 14)
                        .foregroundColor(.green)
                    Text("Online")
                        .font(.system(size: 12))
                }
            }
            Spacer()
            Button {
                shouldShowLogOutOptions.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
            }

        }
        .padding()
        .actionSheet(isPresented:  $shouldShowLogOutOptions) {
            .init(title: Text("Settings"), message: Text("Would you like to Sign out ?"), buttons: [
                .destructive(Text("Sign Out"), action: {
                    print("handle signout")
                    vm.handleSignOut()
                }),
                .cancel()
            ])
        }
        .fullScreenCover(isPresented: $vm.isCurrentlyLoggedOut, onDismiss: nil) {
            LoginView(didCompleteLoginProcess: {
                vm.isCurrentlyLoggedOut = false
                vm.fetchCurrentUser()
                vm.fetchRecentMessages()
            })
        }
    }
    
    
    private var messagesView: some View{
        ScrollView{
            ForEach(vm.recentMessages) { recentMessage in
                VStack {
                    
                    Button {
                        let uid = Auth.auth().currentUser?.uid == recentMessage.fromId ? recentMessage.toId : recentMessage.fromId
                        chatUser = .init(data: ["id" : uid ,
                                                "uid" : uid,
                                                "email" : recentMessage.email,
                                                "profileImageURL" : recentMessage.profileImageUrl])
                        
                        chatLogViewModel.chatUser = chatUser
                        chatLogViewModel.currentUser = vm.chatUser
                        chatLogViewModel.fetchMessages()
                        shouldNavigateToChatLogView.toggle()
                    } label: {
                        HStack(spacing: 16){
                            WebImage(url: URL(string: recentMessage.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipped()
                                .cornerRadius(64)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 64)
                                        .stroke(lineWidth: 1)
                                        .stroke(Color.primary)
                                )
                                .shadow(radius: 5)
//                            Image(systemName: "person.fill")
//                                .font(.system(size: 32))
//                                .padding(8)
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 44)
//                                        .stroke(.primary, lineWidth: 1)
//                                )
                            
                            VStack(alignment: .leading, spacing: 8){
                                Text(recentMessage.username)
                                    .font(.system(size: 16,weight: .bold))
                                    .foregroundColor(.primary)
                                Text(recentMessage.text != "" ? recentMessage.text : recentMessage.selectedImage)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(recentMessage.timeAgo)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.label))
                        }
                    }
 
                    Divider()
                        .padding(.vertical, 8)
                }
                .padding(.horizontal)
            }
            .padding(.bottom,50)
        }
    }
    
    @State var shouldShowNewMessageScreen = false
    
    private var newMessageButton: some View{
        Button {
            shouldShowNewMessageScreen.toggle()
//            let date = Date()
//            let formatter = DateFormatter()
//            formatter.timeStyle = .short
//            formatter.dateStyle = .medium
//            print(formatter.string(from: date))
        } label: {
            HStack {
                Spacer()
                Text("+ New Message")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical)
            .background(.blue)
            .cornerRadius(32)
            .padding(.horizontal)
            .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $shouldShowNewMessageScreen, onDismiss: nil) {
            CreateNewMessageView(didSelectNewUser: { user in
                print(user.email)
                chatUser = user
                chatLogViewModel.chatUser = user
                chatLogViewModel.currentUser = vm.chatUser
                chatLogViewModel.fetchMessages()
                shouldNavigateToChatLogView.toggle()
            })
        }
    }
    
    @State var chatUser: ChatUser?
    
}

struct MainMessagesView_Previews: PreviewProvider {
    static var previews: some View {
        MainMessagesView()
    }
}
