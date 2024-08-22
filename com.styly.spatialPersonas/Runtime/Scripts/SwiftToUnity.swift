import ARKit
import AVFoundation
import Foundation
import SwiftUI
import GroupActivities
import Combine
import CloudKit
import LinkPresentation
import Spatial

@objc public class SwiftToUnity: NSObject
{
    @objc public static let shared = SwiftToUnity()
    @objc public static var model: ShareModel? {
        get {
            Task { @MainActor in
                if _model == nil {
                    _model = ShareModel()
                }
            }
            return _model
        }
    }
    private static var _model: ShareModel?
    
    @objc public func prepareSession() {
            Task { @MainActor in
                do {
                    try await SwiftToUnity.model?.prepareSession()
                } catch {
                    print("Error preparing session: \(error)")
                }
            }
        }
    
    @objc public func endSession() {
            Task { @MainActor in
                do {
                    try await SwiftToUnity.model?.endSession()
                } catch {
                    print("Error ending session: \(error)")
                }
            }
        }
}

enum GroupTextMessageType: Codable {
  case joinGame(id: UUID?, name: String)
  case leaveGame(id: UUID?, name: String)
}

struct GroupMessageActivity: GroupActivity {
  var metadata: GroupActivityMetadata {
    var metadata = GroupActivityMetadata()
    metadata.type = .generic
    metadata.title = "Styly Together"
    metadata.sceneAssociationBehavior = .content(GroupMessageActivity.activityIdentifier)
    metadata.previewImage = UIImage(named: "wholeIcon")?.cgImage
    return metadata
  }
}

struct STYLYTransferable: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        GroupActivityTransferRepresentation { _ in
            GroupMessageActivity()
        }
    }
}

@MainActor
@objc public class ShareModel: NSObject, ObservableObject {
    let activity = GroupMessageActivity()
    var groupSession: GroupSession<GroupMessageActivity>?
    #if os(visionOS)
        var systemCoordinatorConfig: SystemCoordinator.Configuration?
    #endif
    private let groupStateObserver = GroupStateObserver()
    private var subs: Set<AnyCancellable> = []
    @Published var canStartSharePlay: Bool = true
    @Published var enableSharePlay: Bool = true
    @Published var preference: String = "SideBySide"
    var messenger: GroupSessionMessenger?
    private var tasks = Set<Task<Void, Never>>()
    
    override init() {
        super.init()
        groupStateObserver.$isEligibleForGroupSession.sink { [weak self] value in
            self?.enableSharePlay = value
        }.store(in: &subs)
        #if os(visionOS)
            $preference.sink { [weak self] newValue in
                self?.updateTemplateReference(newValue: newValue)
            }.store(in: &subs)
        #endif
        
        Task {
            for await session in GroupMessageActivity.sessions() {
                #if os(visionOS)
                    guard let systemCoordinator = await session.systemCoordinator else { continue }
                    let isSpatial = systemCoordinator.localParticipantState.isSpatial
                    
                    if isSpatial {
                        var configuration = SystemCoordinator.Configuration()
                        switch preference {
                        case "SideBySide":
                            configuration.spatialTemplatePreference = .sideBySide
                        case "None":
                            configuration.spatialTemplatePreference = .none
                        case "Conversational":
                            configuration.spatialTemplatePreference = .conversational
                        default:
                            print("not right")
                        }
                        configuration.supportsGroupImmersiveSpace = true
                        configuration.spatialTemplatePreference = .sideBySide.contentExtent(200)
                        systemCoordinator.configuration = configuration
                        systemCoordinatorConfig = configuration
                    }
                #endif
                
                subs.removeAll()
                let messenger = GroupSessionMessenger(session: session)
                setupMessageSending(messenger: messenger)
                setupMessageReceiving(messenger: messenger)
                session.join()
                self.messenger = messenger
                self.groupSession = session
                canStartSharePlay = false
            }
        }
    }

    #if os(visionOS)
        func updateTemplateReference(newValue: String) {
            switch newValue {
            case "SideBySide":
                systemCoordinatorConfig?.spatialTemplatePreference = .sideBySide
            case "None":
                systemCoordinatorConfig?.spatialTemplatePreference = .none
            case "Conversational":
                systemCoordinatorConfig?.spatialTemplatePreference = .conversational
            default:
                // do nothing
                print("not right")
            }
        }
    #endif
    
    @objc public func prepareSession() async {
        // Await the result of the preparation call.
        switch await activity.prepareForActivation() {
        case .activationDisabled:
            print("Activation is disabled")
        case .activationPreferred:
            do {
                print("Activation is preferred")
                _ = try await activity.activate()
            } catch {
                print("Unable to activate the activity: \(error)")
            }
        case .cancelled:
            print("Cancelled")
        default: ()
        }
    }
    
    @objc public func endSession() {
        tasks.forEach { task in
            task.cancel()
        }
        tasks.removeAll()
        messenger = nil
        groupSession?.end()
        groupSession = nil
        canStartSharePlay = true
        subs.removeAll()
    }
    
    public func setupMessageSending(messenger: GroupSessionMessenger) {
        groupSession?.$activeParticipants.sink{ [weak self] activeParticipants in
          guard let self = self else { return }
          self.messengerSend(messenger: messenger, GroupTextMessageType.joinGame(id: self.groupSession?.localParticipant.id, name: "Player"))
        }.store(in: &subs)
      }
      
      // Handle messages arriving from GroupSessionMessenger
      public func setupMessageReceiving(messenger: GroupSessionMessenger) {
        let task = Task.detached {
          // task to receive message via group session messenger
          for await (message, _) in messenger.messages(of: GroupTextMessageType.self) {
            switch message {
            case .joinGame(let id, let name):
              await self.handleJoinMessage(id: id, name: name)
            case .leaveGame(let id, let name):
              await self.handleLeaveMessage(id: id, name: name)
            }
          }
        }
        tasks.insert(task)
      }
      
      // For use with existing groupSessionMessenger
      func groupMessengerSend(_ value: GroupTextMessageType) {
        guard let groupmessenger = messenger else {
          return
        }
        messengerSend(messenger: groupmessenger, value)
      }
      
      // Reusable code for messenger sending any message
      func messengerSend( messenger: GroupSessionMessenger, _ value: GroupTextMessageType) {
        Task.init {
          do {
            // catch any time self joins a game, and send that:
            try await messenger.send(value)
            // GroupTextMessageType.sendText(text: text)
          } catch {
            print (error)
          }
        };
      }
      
      // Player Joins Game:
      @objc public func handleJoinMessage(id:UUID?, name: String) {
        print("Handle new player joining, named: \(name)")
      }
      
      // Player Leaves Game:
      @objc public func handleLeaveMessage(id:UUID?, name: String) {
        print("Goodbye: \(name)")
      }
}