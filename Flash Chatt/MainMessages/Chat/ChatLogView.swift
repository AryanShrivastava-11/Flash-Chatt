//
//  ChatLogView.swift
//  Flash Chatt
//
//  Created by Aryan Shrivastava on 15/01/22.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import SDWebImageSwiftUI

class ChatLogViewModel: ObservableObject{
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    @Published var selectedImage: UIImage? = nil
    @Published var count = 0 //used to scroll down to last message
    
    var chatUser: ChatUser?
    var currentUser: ChatUser?
    
    init(chatUser: ChatUser? , currentUser: ChatUser?){
        self.chatUser = chatUser
        self.currentUser = currentUser
        
        fetchMessages()
    }
    
    var firestoreListener: ListenerRegistration?
    
    func fetchMessages(){
        guard let fromId = Auth.auth().currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        firestoreListener?.remove()
        chatMessages.removeAll()
        
        firestoreListener = Firestore.firestore().collection("messages").document(fromId).collection(toId).order(by: "timestamp").addSnapshotListener { querySnapshot, error in
            if let err = error{
                print("Failed to listen to messages: \(err.localizedDescription)")
                self.errorMessage = "Failed to listen to messages: \(err.localizedDescription)"
                return
            }
            
            querySnapshot?.documentChanges.forEach({ change in
                if change.type == .added{
                    let data = change.document.data()
                    let documentId = change.document.documentID
                    print(data["timestamp"])
                    
                    
                    let chatMessage = ChatMessage(documentId: documentId, data: data)
                    
                    self.chatMessages.append(chatMessage)
                    print("Appending messages to chatMessage ")
                }
            })
            
            //            querySnapshot?.documents.forEach({ queryDocumentSnapshot in
            //                let data = queryDocumentSnapshot.data()
            //                let documentId = queryDocumentSnapshot.documentID
            //
            //                let chatMessage = ChatMessage(documentId: documentId, data: data)
            //                self.chatMessages.append(chatMessage)
            //            })
            
            DispatchQueue.main.async {
                self.count = self.count + 1
            }
        }
    }
    
    func storingTheImageIntoFirebaseStorage(){
        guard let fromId = Auth.auth().currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        var imageUrl = ""
        
        //storing image to Firebase Storage
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Storage.storage().reference(withPath: uid)
        guard let imageData = selectedImage?.jpegData(compressionQuality: 0.5) else { return }
        
        ref.putData(imageData, metadata: nil) { metaData, error in
            if let err = error{
                print("Failed to push image to Storage: \(err)")
                return
            }
            ref.downloadURL { url, error in
                if let err = error {
                    print("Failed to retrieve downloadURL: \(err)")
                    return
                }
                
                print("Successfully stored image with url: \(url) in Firebase Storage")
//                print(url?.absoluteString)
                
                if let url = url {
                    imageUrl = url.absoluteString
                    self.handleSendImage(imageUrl: imageUrl)
                }
                
            }
            
        }
        //Code related to image storing in FIrebase Storgae completed
        
        
        
        
    }
    
    private func handleSendImage(imageUrl: String){
        guard let fromId = Auth.auth().currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let document = Firestore.firestore().collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = [FirebaseConstants.fromId : fromId ,
                           FirebaseConstants.toId : toId ,
                           FirebaseConstants.text : "" ,
                           "selectedImageUrl" : imageUrl ,
                           "timestamp" : Date()] as [String : Any]
        
        document.setData(messageData) { error in
            if let err = error{
                self.errorMessage = "Failed to save message into Firebase:\(err.localizedDescription)"
                return
            }
            print("Successfully saved current user selected image in firestore")
            
            self.persistRecentSelectedImage()
            
            self.chatText = ""
            self.selectedImage = nil
            
            self.count = self.count + 1
        }
        let recipientMessageDocuments = Firestore.firestore().collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        recipientMessageDocuments.setData(messageData) { error in
            if let err = error{
                self.errorMessage = "Failed to save message into Firebase:\(err.localizedDescription)"
                return
            }
            print("Saved recipient selected image in firestore as well")
        }
    }
    
    func persistRecentSelectedImage() {
        
        guard let chatUser = chatUser else { return }
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let toId = chatUser.uid
        
        let document = Firestore.firestore()
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            FirebaseConstants.timestamp : Timestamp(),
            FirebaseConstants.text : "",
            "selectedImage" : "Image sent",
            FirebaseConstants.fromId : uid,
            FirebaseConstants.toId : toId,
            FirebaseConstants.profileImageUrl : chatUser.profileImageURL,
            FirebaseConstants.email : chatUser.email
        ] as [String : Any]
        
        //similar kind of dictionary is required for recipient of this message
        
        document.setData(data) { error in
            if let err = error{
                self.errorMessage = "Failed to save recent message: \(err.localizedDescription)"
                print("Failed to save recent message: \(err.localizedDescription)")
                return
            }
            print("Recent Selected Image Message saved for current user")
            
        }
        
        guard let currentUser = currentUser else { return }
        
        //        print(currentUser.profileImageURL)
        
        let recepientRecentMessageDict = [
            FirebaseConstants.timestamp : Timestamp(),
            FirebaseConstants.text : "",
            "selectedImage" : "Recieved an image",
            FirebaseConstants.fromId : uid,
            FirebaseConstants.toId : toId,
            FirebaseConstants.profileImageUrl : currentUser.profileImageURL,
            FirebaseConstants.email : currentUser.email
        ] as [String : Any]
        
        Firestore.firestore()
            .collection("recent_messages")
            .document(toId)
            .collection("messages")
            .document(currentUser.uid)
            .setData(recepientRecentMessageDict) { error in
                if let err = error{
                    print("Failed to save recipient recent message: \(err.localizedDescription)")
                    return
                }
                print("Recent Selected Image Message saved for recipient as well")
            }
    }
    
    func handleSend(){
        print(chatText)
        guard let fromId = Auth.auth().currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let document = Firestore.firestore().collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = [FirebaseConstants.fromId : fromId , FirebaseConstants.toId : toId , FirebaseConstants.text : chatText , "selectedImageUrl" : "" ,"timestamp" : Date()] as [String : Any]
        
        document.setData(messageData) { error in
            if let err = error{
                self.errorMessage = "Failed to save message into Firebase:\(err.localizedDescription)"
                return
            }
            print("Successfully saved current user sending message")
            
            self.persistRecentMessages()
            
            self.chatText = ""
            self.selectedImage = nil
            self.count = self.count + 1
        }
        
        let recipientMessageDocuments = Firestore.firestore().collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        recipientMessageDocuments.setData(messageData) { error in
            if let err = error{
                self.errorMessage = "Failed to save message into Firebase:\(err.localizedDescription)"
                return
            }
            print("Saved recipient message as well")
        }
    }
    
    private func persistRecentMessages() {
        
        guard let chatUser = chatUser else { return }
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let toId = chatUser.uid
        
        let document = Firestore.firestore()
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            FirebaseConstants.timestamp : Timestamp(),
            FirebaseConstants.text : chatText,
            "selectedImage" : "",
            FirebaseConstants.fromId : uid,
            FirebaseConstants.toId : toId,
            FirebaseConstants.profileImageUrl : chatUser.profileImageURL,
            FirebaseConstants.email : chatUser.email
        ] as [String : Any]
        
        //similar kind of dictionary is required for recipient of this message
        
        document.setData(data) { error in
            if let err = error{
                self.errorMessage = "Failed to save recent message: \(err.localizedDescription)"
                print("Failed to save recent message: \(err.localizedDescription)")
                return
            }
            print("Recent Message saved for current user")

        }
        
        guard let currentUser = currentUser else { return }
        
//        print(currentUser.profileImageURL)
        
        let recepientRecentMessageDict = [
            FirebaseConstants.timestamp : Timestamp(),
            FirebaseConstants.text : chatText,
            "selectedImage" : "",
            FirebaseConstants.fromId : uid,
            FirebaseConstants.toId : toId,
            FirebaseConstants.profileImageUrl : currentUser.profileImageURL,
            FirebaseConstants.email : currentUser.email
        ] as [String : Any]
        
        Firestore.firestore()
            .collection("recent_messages")
            .document(toId)
            .collection("messages")
            .document(currentUser.uid)
            .setData(recepientRecentMessageDict) { error in
                if let err = error{
                    print("Failed to save recipient recent message: \(err.localizedDescription)")
                    return
                }
                print("Recent Message saved for recipient as well")
            }
    }
}

struct ChatLogView: View {
    
//    var chatUser: ChatUser?
//    var currentUser: ChatUser?
//    
//    init(chatUser: ChatUser?, currentUser: ChatUser?){
//        self.currentUser = currentUser
//        
//        self.chatUser = chatUser
//        vm = .init(chatUser: chatUser, currentUser: currentUser)
//        
//    }
    @State var shouldShowImagePicker = false
    @ObservedObject var vm: ChatLogViewModel
//    @State var selectedImage: UIImage?
    @State var isFocused:Bool = false

    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            messagesView
                .navigationTitle(vm.chatUser?.email ?? "")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onDisappear {
            vm.firestoreListener?.remove()
        }
        .sheet(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $vm.selectedImage)
                .ignoresSafeArea()
        }
    }
    
    static let emptyScrollToString = "Empty"
    
    private var messagesView: some View {
        ScrollView{
            ScrollViewReader { scrollViewProxy in
                ForEach(vm.chatMessages){ message in
                    MessageView(message: message)
                }
                HStack{
                    Spacer()
                }
                .id(Self.emptyScrollToString)
                .onReceive(vm.$count) { _ in
                    withAnimation(.easeOut(duration: 0.5)) {
                        scrollViewProxy.scrollTo(Self.emptyScrollToString, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color("background2"))
        .safeAreaInset(edge: .bottom) {
            chatBottomBar
                .background(Color(.systemBackground).ignoresSafeArea())
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
            Button {
                shouldShowImagePicker.toggle()
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24))
                    .opacity(0.7)
            }
            ZStack {
                DescriptionPlaceholder(selectedImage: $vm.selectedImage)
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            //            TextField("Chat Description", text: $chatText)
            Button {
                if vm.chatText != "" {
                    vm.handleSend()
                }else if vm.selectedImage != nil {
                    vm.storingTheImageIntoFirebaseStorage()
                }
                
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(5)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct DescriptionPlaceholder: View {
    
    @Binding var selectedImage: UIImage?
    
    var isSelectedImage: Bool { return (selectedImage != nil) ? true : false}
    
    var body: some View {
        HStack {
            Text(isSelectedImage ? "Image Selected" : "Description")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
            Spacer()
        }
    }
}

struct MessageView: View {
    
    let message: ChatMessage
    
    var body: some View {
        VStack {
            if message.fromId == Auth.auth().currentUser?.uid{
                if message.selectedImageUrl == ""{
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack {
                                Text(message.text)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(.blue)
                            .cornerRadius(8)
                            Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10, weight: .light, design: .rounded))
                        }
                    }
                }else{
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack {
                                WebImage(url: URL(string: message.selectedImageUrl))
                                    .resizable()
                                    .frame(width: 180, height: 180)
                                    .scaledToFill()
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(.secondary, lineWidth: 3))
                            }
//                            .padding()
//                            .background(.blue)
                            .cornerRadius(8)
                            Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10, weight: .light, design: .rounded))
                        }
                    }
                }
//                if let selectedImage = selectedImage {
//                    HStack{
//                        Spacer()
//                        Image(uiImage: selectedImage)
//                            .resizable()
//                            .frame(width: 180, height: 180)
//                            .scaledToFill()
//                            .cornerRadius(10)
//                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
//                                        .stroke(.secondary, lineWidth: 3))
//                    }
//
//                }
                    
            }else {
                if message.selectedImageUrl == ""{
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                Text(message.text)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(.green)
                            .cornerRadius(8)
                            Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10, weight: .light, design: .rounded))
                        }
                        Spacer()
                        
                    }
                }
                else{
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                WebImage(url: URL(string: message.selectedImageUrl))
                                    .resizable()
                                    .frame(width: 180, height: 180)
                                    .scaledToFill()
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(.secondary, lineWidth: 3))
                            }
//                            .padding()
//                            .background(.green)
                            .cornerRadius(8)
                            Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10, weight: .light, design: .rounded))
                        }
                        Spacer()
                        
                    }
                }
                
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
//            ChatLogView(chatUser: ChatUser(data:
//                                            ["uid" : "Sj4BhfKwEigFYYG3ymnjLqv7eqB2" ,
//                                             "email" : "testing100@gmail.com"]), currentUser: <#ChatUser?#>)
            ChatLogView(vm: ChatLogViewModel(chatUser:
                                                ChatUser(data: ["uid" :
                                                                    "XwVNX4cYnYNA9m3ohodTGBqFChG3",
                                                                "email" : "rose@gmail.com",
                                                                "profileImageURL" : "https://firebasestorage.googleapis.com:443/v0/b/flash-chatt-6e5de.appspot.com/o/XwVNX4cYnYNA9m3ohodTGBqFChG3?alt=media&token=64387612-1591-4b29-87e1-694b6962a726"]),
                                             currentUser:
                                                ChatUser(data: ["uid" :
                                                                    "BmyZczRNKXSx6JSWaCWN7Zlrju73",
                                                                "email" :
                                                                    "waterfall@gmail.com",
                                                                "profileImageURL" : "https://firebasestorage.googleapis.com:443/v0/b/flash-chatt-6e5de.appspot.com/o/BmyZczRNKXSx6JSWaCWN7Zlrju73?alt=media&token=87d52267-3b31-4290-87db-f9acc8fe29f5"])))
            MainMessagesView()
        }
    }
}
