//
//  ContactDetails.swift
//  Monal
//
//  Created by Jan on 22.10.21.
//  Copyright © 2021 Monal.im. All rights reserved.
//

import UIKit
import SwiftUI
import monalxmpp

struct ContactDetails: View {
    var delegate: SheetDismisserProtocol
    @StateObject var contact: ObservableKVOWrapper<MLContact>
    @State private var showingBlockContactConfirmation = false
    @State private var showingCannotBlockAlert = false
    @State private var showingRemoveContactConfirmation = false
    @State private var showingAddContactConfirmation = false
    @State private var showingClearHistoryConfirmation = false
    @State private var showingResetOmemoSessionConfirmation = false
    @State private var showingCannotEncryptAlert = false
    @State private var showingShouldDisableEncryptionAlert = false

    var body: some View {
        Form {
            Section {
                ContactDetailsHeader(delegate:delegate, contact:contact)
            }
                
            // info/nondestructive buttons
            Section {
                Button(action: {
                    if(contact.isGroup) {
                        if(!contact.isMuted && !contact.isMentionOnly) {
                            contact.obj.toggleMentionOnly(true)
                        } else if(!contact.isMuted && contact.isMentionOnly) {
                            contact.obj.toggleMentionOnly(false)
                            contact.obj.toggleMute(true)
                        } else {
                            contact.obj.toggleMentionOnly(false)
                            contact.obj.toggleMute(false)
                        }
                    } else {
                        contact.obj.toggleMute(!contact.isMuted)
                    }
                }) {
                    HStack {
                        if(contact.isMuted) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundColor(.red)
                            Text("Contact is muted")
                                .foregroundColor(.accentColor)
                        } else if(contact.isGroup && contact.isMentionOnly) {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.accentColor)
                            Text("Group/Channel is mention only")
                                .foregroundColor(.accentColor)
                        } else {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.green)
                            Text("Contact is not muted")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                //.buttonStyle(BorderlessButtonStyle())
                
#if !DISABLE_OMEMO
                if(!contact.isGroup || (contact.isGroup && contact.mucType == "group")) {
                    Button(action: {
                        if(contact.isEncrypted) {
                            showingShouldDisableEncryptionAlert = true
                        } else {
                            showingCannotEncryptAlert = !contact.obj.toggleEncryption(!contact.isEncrypted)
                        }
                    }) {
                        HStack {
                            if contact.isEncrypted {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.green)
                                Text("Messages are encrypted")
                                    .foregroundColor(.accentColor)
                            } else {
                                Image(systemName: "lock.open.fill")
                                    .foregroundColor(.red)
                                Text("Messages are NOT encrypted")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .alert(isPresented: $showingCannotEncryptAlert) {
                        Alert(title: Text("No OMEMO keys found"), message: Text("This contact may not support OMEMO encrypted messages. Please try again in a few seconds."), dismissButton: .default(Text("Close")))
                    }
                    .actionSheet(isPresented: $showingShouldDisableEncryptionAlert) {
                        ActionSheet(
                            title: Text("Disable encryption?"),
                            message: Text("Do you really want to disable encryption for this contact?"),
                            buttons: [
                                .cancel(
                                    Text("No, keep encryption activated"),
                                    action: { }
                                ),
                                .destructive(
                                    Text("Yes, deactivate encryption"),
                                    action: {
                                        showingCannotEncryptAlert = !contact.obj.toggleEncryption(!contact.isEncrypted)
                                    }
                                )
                            ]
                        )
                    }
                    //.buttonStyle(BorderlessButtonStyle())
                }
#endif
                
                if(!contact.isGroup && !contact.isSelfChat) {
                    TextField("Change Nickname", text: $contact.nickNameView)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .addClearButton(text:$contact.nickNameView)
                }
                
                Button(contact.isPinned ? "Unpin Chat" : "Pin Chat") {
                    contact.obj.togglePinnedChat(!contact.isPinned);
                }

                if(contact.obj.isGroup && contact.obj.mucType == "group") {
                    NavigationLink(destination: LazyClosureView(MemberList(mucContact: contact))) {
                        Text("Group Members")
                    }
                }
#if !DISABLE_OMEMO
                if(!contact.isGroup) {
                    NavigationLink(destination: LazyClosureView(OmemoKeys(contact: contact))) {
                        Text(contact.isSelfChat ? "Own Encryption Keys" : "Encryption Keys")
                    }
                } else if(contact.mucType == "group") {
                    NavigationLink(destination: LazyClosureView(OmemoKeys(contact: contact))) {
                        Text("Encryption Keys")
                    }
                }
#endif
                
                if(!contact.isGroup && !contact.isSelfChat) {
                    NavigationLink(destination: LazyClosureView(ContactResources(contact: contact))) {
                        Text("Resources")
                    }
                }
                
                let sharedUrl = HelperTools.getSharedDocumentsURL(forPathComponents:[MLXMPPManager.sharedInstance().getConnectedAccount(forID:contact.accountId)!.connectionProperties.identity.jid, contact.contactDisplayName as String])
                if UIApplication.shared.canOpenURL(sharedUrl) && FileManager.default.fileExists(atPath:sharedUrl.path) {
                    Button(action: {
                            UIApplication.shared.open(sharedUrl, options:[:])
                    }) {
                        Text("Show shared Media and Files")
                    }
                }
                
                NavigationLink(destination: LazyClosureView(BackgroundSettings(contact:contact, delegate:delegate))) {
                    Text("Change Contact Background")
                }
            }
            .listStyle(.plain)

            Section { // the destructive section...
                if !contact.isSelfChat {
                    Button(action: {
                        if(!contact.isBlocked) {
                            showingBlockContactConfirmation = true
                        } else {
                            showingCannotBlockAlert = !contact.obj.toggleBlocked(!contact.isBlocked)
                        }
                    }) {
                        if(!contact.isBlocked) {
                            Text("Block Contact")
                                .foregroundColor(.red)
                        } else {
                            Text("Unblock Contact")
                        }
                    }
                    .alert(isPresented: $showingCannotBlockAlert) {
                        Alert(title: Text("Blocking/Unblocking Not Supported"), message: Text("The server does not support blocking (XEP-0191)."), dismissButton: .default(Text("Close")))
                    }
                    .actionSheet(isPresented: $showingBlockContactConfirmation) {
                        ActionSheet(
                            title: Text("Block Contact"),
                            message: Text("Do you really want to block this contact? You won't receive any messages from this contact."),
                            buttons: [
                                .cancel(),
                                .destructive(
                                    Text("Yes"),
                                    action: {
                                        showingCannotBlockAlert = !contact.obj.toggleBlocked(!contact.isBlocked)
                                    }
                                )
                            ]
                        )
                    }

                    Group {
                        if(contact.isInRoster) {
                            Button(action: {
                                showingRemoveContactConfirmation = true
                            }) {
                                if(contact.isGroup) {
                                    if(contact.mucType == "group") {
                                        Text("Leave Group")
                                            .foregroundColor(.red)
                                    } else {
                                        Text("Leave Channel")
                                            .foregroundColor(.red)
                                    }
                                } else {
                                    Text("Remove from contacts")
                                        .foregroundColor(.red)
                                }
                            }
                            .actionSheet(isPresented: $showingRemoveContactConfirmation) {
                                ActionSheet(
                                    title: Text(contact.isGroup ? NSLocalizedString("Leave this conversation", comment: "") : String(format: NSLocalizedString("Remove %@ from contacts?", comment: ""), contact.contactJid)),
                                        message: Text(contact.isGroup ? NSLocalizedString("You will no longer receive messages from this conversation", comment: "") : NSLocalizedString("They will no longer see when you are online. They may not be able to send you encrypted messages.", comment: "")),
                                    buttons: [
                                        .cancel(),
                                        .destructive(
                                            Text("Yes"),
                                            action: {
                                                contact.obj.removeFromRoster()      //this will dismiss the chatview via kMonalContactRemoved notification
                                                self.delegate.dismiss()
                                            }
                                        )
                                    ]
                                )
                            }
                        } else {
                            Button(action: {
                                showingAddContactConfirmation = true
                            }) {
                                if(contact.isGroup) {
                                    if(contact.mucType == "group") {
                                        Text("Join Group")
                                    } else {
                                        Text("Join Channel")
                                    }
                                } else {
                                    Text("Add to contacts")
                                }
                            }
                            .actionSheet(isPresented: $showingAddContactConfirmation) {
                                ActionSheet(
                                    title: Text(contact.isGroup ? (contact.mucType == "group" ? NSLocalizedString("Join Group", comment: "") : NSLocalizedString("Join Channel", comment: "")) : String(format: NSLocalizedString("Add %@ to your contacts?", comment: ""), contact.contactJid)),
                                    message: Text(contact.isGroup ? NSLocalizedString("You will receive subsequent messages from this conversation", comment: "") : NSLocalizedString("They will see when you are online. They will be able to send you encrypted messages.", comment: "")),
                                    buttons: [
                                        .cancel(),
                                        .default(
                                            Text("Yes"),
                                            action: {
                                                contact.obj.addToRoster()
                                            }
                                        ),
                                    ]
                                )
                            }
                        }
                    }
                }

                Button(action: {
                    showingClearHistoryConfirmation = true
                }) {
                    if(contact.isGroup) {
                        if(contact.obj.mucType == "group") {
                            Text("Clear chat history of this group")
                        } else {
                            Text("Clear chat history of this channel")
                        }
                    } else {
                        Text("Clear chat history of this contact")
                    }
                }
                .foregroundColor(.red)
                .actionSheet(isPresented: $showingClearHistoryConfirmation) {
                    ActionSheet(
                        title: Text("Clear History"),
                        message: Text("Do you really want to clear all messages exchanged in this conversation? If using OMEMO you won't even be able to load them from your server again."),
                        buttons: [
                            .cancel(),
                            .destructive(
                                Text("Yes"),
                                action: {
                                    contact.obj.clearHistory()
                                }
                            )
                        ]
                    )
                }
            }
            
#if !DISABLE_OMEMO
            //omemo debug stuff, should be removed in a few months
            Section {
                // only display omemo session reset button on 1:1 and private groups
                if(contact.obj.isGroup == false || (contact.isGroup && contact.mucType == "group"))
                {
                    Button(action: {
                        showingResetOmemoSessionConfirmation = true
                    }) {
                        Text("Reset OMEMO session")
                            .foregroundColor(.red)
                    }
                    .actionSheet(isPresented: $showingResetOmemoSessionConfirmation) {
                        ActionSheet(
                            title: Text("Reset OMEMO session"),
                            message: Text("Do you really want to reset the OMEMO session? You should only reset the connection if you know what you are doing!"),
                            buttons: [
                                .cancel(),
                                .destructive(
                                    Text("Yes"),
                                    action: {
                                        if let account = MLXMPPManager.sharedInstance().getConnectedAccount(forID: contact.accountId) {
                                            account.omemo.clearAllSessions(forJid:contact.contactJid);
                                        }
                                    }
                                )
                            ]
                        )
                    }
                }
            }
#endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitle(contact.contactDisplayName as String, displayMode: .inline)
    }
}

struct ContactDetails_Previews: PreviewProvider {
    static var delegate = SheetDismisserProtocol()
    static var previews: some View {
        ContactDetails(delegate:delegate, contact:ObservableKVOWrapper<MLContact>(MLContact.makeDummyContact(0)))
        ContactDetails(delegate:delegate, contact:ObservableKVOWrapper<MLContact>(MLContact.makeDummyContact(1)))
        ContactDetails(delegate:delegate, contact:ObservableKVOWrapper<MLContact>(MLContact.makeDummyContact(2)))
        ContactDetails(delegate:delegate, contact:ObservableKVOWrapper<MLContact>(MLContact.makeDummyContact(3)))
        ContactDetails(delegate:delegate, contact:ObservableKVOWrapper<MLContact>(MLContact.makeDummyContact(4)))
    }
}
