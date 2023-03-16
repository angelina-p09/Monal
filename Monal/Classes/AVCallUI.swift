//
//  AVCallUI.swift
//  Monal
//
//  Created by Thilo Molitor on 20.12.22.
//  Copyright © 2021 Monal.im. All rights reserved.
//
import monalxmpp

import SwiftUI
import CocoaLumberjack
import WebRTC
import AVFoundation
import CallKit
import AVKit

struct AVCallUI: View {
    @StateObject private var call: ObservableKVOWrapper<MLCall>
    @StateObject private var contact: ObservableKVOWrapper<MLContact>
    @State private var audioPlayer: AVAudioPlayer!
    private var delegate: SheetDismisserProtocol
    private var appDelegate: MonalAppDelegate
    private var formatter: DateComponentsFormatter
    
    var someValue:Int?

    init(delegate: SheetDismisserProtocol, call: MLCall) {
        _call = StateObject(wrappedValue: ObservableKVOWrapper(call))
        _contact = StateObject(wrappedValue: ObservableKVOWrapper(call.contact))
        self.delegate = delegate
        self.appDelegate = UIApplication.shared.delegate as! MonalAppDelegate
        self.formatter = DateComponentsFormatter()
        self.formatter.allowedUnits = [.hour, .minute, .second]
        self.formatter.unitsStyle = .positional
        self.formatter.zeroFormattingBehavior = .pad
    }

    var body: some View {
        ZStack {
            Color.background
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Group {
                    Spacer().frame(height: 24)
                    
                    HStack {
                        switch MLCallDirection(rawValue:call.direction) {
                            case .incoming:
                                Image(systemName: "phone.arrow.down.left")
                                    .resizable()
                                    .frame(width: 20.0, height: 20.0)
                                    .foregroundColor(.primary)
                            case .outgoing:
                                Image(systemName: "phone.arrow.up.right")
                                    .resizable()
                                    .frame(width: 20.0, height: 20.0)
                                    .foregroundColor(.primary)
                            default:        //should never be reached
                                Text("")
                        }
                        
                        Spacer().frame(width: 20)
                        
                        Text(contact.contactDisplayName as String)
                            .font(.largeTitle)
                            .foregroundColor(.primary)
                        
                        Spacer().frame(width: 20)
                        
                        Button(action: {
                            self.delegate.dismissWithoutAnimation()
                            if let activeChats = self.appDelegate.activeChats {
                                activeChats.presentChat(with:self.contact.obj)
                            }
                        }, label: {
                            Image(systemName: "text.bubble")
                                .resizable()
                                .frame(width: 28.0, height: 28.0)
                                .foregroundColor(.primary)
                        })
                    }
                    
                    Spacer().frame(height: 16)
                    
                    //this is needed because ObservableKVOWrapper somehow extracts an NSNumber? from it's wrapped object
                    //which results in a runtime error when trying to cast NSNumber? to MLCallState
                    switch MLCallState(rawValue:call.state) {
                        case .discovering:
                            Text("Discovering devices...")
                            .bold()
                            .foregroundColor(.primary)
                        case .ringing:
                            Text("Ringing...")
                            .bold()
                            .foregroundColor(.primary)
                        case .connecting:
                            Text("Connecting...")
                            .bold()
                            .foregroundColor(.primary)
                        case .reconnecting:
                            Text("Reconnecting...")
                            .bold()
                            .foregroundColor(.primary)
                        case .connected:
                            Text("Connected: \(formatter.string(from: TimeInterval(call.durationTime as UInt))!)")
                            .bold()
                            .foregroundColor(.primary)
                        case .finished:
                            switch MLCallFinishReason(rawValue:call.finishReason) {
                                case .unknown:
                                    Text("Call ended for an unknown reason")
                                    .bold()
                                    .foregroundColor(.primary)
                                case .normal:
                                    Text("Call ended, duration: \(formatter.string(from: TimeInterval(call.durationTime as UInt))!)")
                                    .bold()
                                    .foregroundColor(.primary)
                                case .connectivityError:
                                    Text("Call ended: connection failed")
                                    .bold()
                                    .foregroundColor(.primary)
                                case .unanswered:
                                    Text("Call was not answered")
                                    .bold()
                                    .foregroundColor(.primary)
                                case .answeredElsewhere:
                                    Text("Call ended: answered with other device")
                                    .bold()
                                    .foregroundColor(.primary)
                                case .retracted:
                                    //this will only be displayed for timer-induced retractions,
                                    //reflect that in our text instead of using some generic "hung up"
                                    //Text("Call ended: hung up")
                                    Text("Call ended: remote busy")
                                    .bold()
                                    .foregroundColor(.primary)
                                case .rejected:
                                    Text("Call ended: remote busy")
                                    .bold()
                                    .foregroundColor(.primary)
                                case .declined:
                                    Text("Call ended: declined")
                                    .bold()
                                    .foregroundColor(.primary)
                                default:        //should never be reached
                                    Text("")
                            }
                        default:        //should never be reached
                            Text("")
                    }
                    
                    Spacer().frame(height: 48)
                    
                    Image(uiImage: contact.avatar)
                        .resizable()
                        .frame(minWidth: 100, idealWidth: 150, maxWidth: 200, minHeight: 100, idealHeight: 150, maxHeight: 200, alignment: .center)
                        .scaledToFit()
                        .shadow(radius: 7)
                    
                    Spacer()
                }
                
                if MLCallState(rawValue:call.state) == .finished {
                    HStack() {
                        Spacer()
                        
                        Button(action: {
                            self.delegate.dismissWithoutAnimation()
                            if let activeChats = self.appDelegate.activeChats {
                                activeChats.call(contact.obj)
                            }                            
                        }) {
                            if #available(iOS 15, *) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .resizable()
                                    .frame(width: 64.0, height: 64.0)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .green)
                                    .shadow(radius: 7)
                            } else {
                                ZStack {
                                    Image(systemName: "circle.fill")
                                        .resizable()
                                        .frame(width: 64.0, height: 64.0)
                                        .accentColor(.white)
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .resizable()
                                        .frame(width: 64.0, height: 64.0)
                                        .accentColor(.green)
                                        .shadow(radius: 7)
                                }
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Spacer().frame(width: 64)

                        Button(action: {
                            //delegate.dismissWithoutAnimation()
                            print("\(String(describing:someValue!))")
                        }) {
                            if #available(iOS 15, *) {
                                Image(systemName: "x.circle.fill")
                                    .resizable()
                                    .frame(width: 64.0, height: 64.0)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .red)
                                    .shadow(radius: 7)
                            } else {
                                ZStack {
                                    Image(systemName: "circle.fill")
                                        .resizable()
                                        .frame(width: 64.0, height: 64.0)
                                        .accentColor(.white)
                                    Image(systemName: "x.circle.fill")
                                        .resizable()
                                        .frame(width: 64.0, height: 64.0)
                                        .accentColor(.red)
                                        .shadow(radius: 7)
                                }
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Spacer()
                    }
                } else {
                    HStack() {
                        Spacer()
                        
                        if MLCallState(rawValue:call.state) == .connected || MLCallState(rawValue:call.state) == .reconnecting {
                            Button(action: {
                                call.muted = !call.muted
                            }) {
                                if #available(iOS 15, *) {
                                    Image(systemName: call.muted ? "mic.circle.fill" : "mic.slash.circle.fill")
                                        .resizable()
                                        .frame(width: 64.0, height: 64.0)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(call.muted ? .black : .white, call.muted ? .white : .black)
                                        .shadow(radius: 7)
                                } else {
                                    ZStack {
                                        Image(systemName: "circle.fill")
                                            .resizable()
                                            .frame(width: 64.0, height: 64.0)
                                            .accentColor(call.muted ? .black : .white)
                                        Image(systemName: call.muted ? "mic.circle.fill" : "mic.circle.fill")
                                            .resizable()
                                            .frame(width: 64.0, height: 64.0)
                                            .accentColor(call.muted ? .white : .black)
                                            .shadow(radius: 7)
                                    }
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            
                            Spacer().frame(width: 32)
                        }
                        
                        Button(action: {
                            call.obj.end()
                            //self.delegate.dismissWithoutAnimation()
                            self.audioPlayer.play()
                            DDLogError("player: \(String(describing:self.audioPlayer))")
                        }) {
                            if #available(iOS 15, *) {
                                Image(systemName: "phone.down.circle.fill")
                                    .resizable()
                                    .frame(width: 64.0, height: 64.0)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .red)
                                    .shadow(radius: 7)
                            } else {
                                ZStack(alignment: .center) {
                                    Image(systemName: "circle.fill")
                                        .resizable()
                                        .frame(width: 64.0, height: 64.0)
                                        .accentColor(.white)
                                    Image(systemName: "phone.down.circle.fill")
                                        .resizable()
                                        .frame(width: 64.0, height: 64.0)
                                        .accentColor(.red)
                                        .shadow(radius: 7)
                                }
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        if MLCallState(rawValue:call.state) == .connected || MLCallState(rawValue:call.state) == .reconnecting {
                            Spacer().frame(width: 32)
                            Button(action: {
                                call.speaker = !call.speaker
                            }) {
                                if #available(iOS 15, *) {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .resizable()
                                        .frame(width: 64.0, height: 64.0)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(call.speaker ? .black : .white, call.speaker ? .white : .black)
                                        .shadow(radius: 7)
                                } else {
                                    ZStack {
                                        Image(systemName: "circle.fill")
                                            .resizable()
                                            .frame(width: 64.0, height: 64.0)
                                            .accentColor(call.speaker ? .black : .white)
                                        Image(systemName: "speaker.wave.2.circle.fill")
                                            .resizable()
                                            .frame(width: 64.0, height: 64.0)
                                            .accentColor(call.speaker ? .white : .black)
                                            .shadow(radius: 7)
                                    }
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer().frame(height: 32)
            }
        }
        .onAppear {
            //force portrait mode and lock ui there
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            self.appDelegate.orientationLock = .portrait
            let sound = Bundle.main.url(forResource:"alert3", withExtension:"aif", subdirectory:"AlertSounds")
            self.audioPlayer = try! AVAudioPlayer(contentsOf:sound!)
        }
        .onDisappear {
            //allow all orientations again
            self.appDelegate.orientationLock = .all
        }
    }
}

struct AVCallUI_Previews: PreviewProvider {
    static var delegate = SheetDismisserProtocol()
    static var previews: some View {
        AVCallUI(delegate:delegate, call:MLCall.makeDummyCall(0))
    }
}
