import CoreData
import Foundation

enum CoreDataModel {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        let bookmarkEntity = NSEntityDescription()
        bookmarkEntity.name = "SourceBookmarkEntity"
        bookmarkEntity.managedObjectClassName = NSStringFromClass(SourceBookmarkEntity.self)
        
        let bDataAttr = NSAttributeDescription()
        bDataAttr.name = "bookmarkData"
        bDataAttr.attributeType = .binaryDataAttributeType
        bDataAttr.isOptional = false
        bookmarkEntity.properties = [bDataAttr]
        
        let trackEntity = NSEntityDescription()
        trackEntity.name = "TrackEntity"
        trackEntity.managedObjectClassName = NSStringFromClass(TrackEntity.self)
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false
        
        let urlAttr = NSAttributeDescription()
        urlAttr.name = "urlPath"
        urlAttr.attributeType = .stringAttributeType
        urlAttr.isOptional = false
        
        let bookmarkAttr = NSAttributeDescription()
        bookmarkAttr.name = "bookmarkData"
        bookmarkAttr.attributeType = .binaryDataAttributeType
        bookmarkAttr.isOptional = true
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = true
        
        let artistAttr = NSAttributeDescription()
        artistAttr.name = "artist"
        artistAttr.attributeType = .stringAttributeType
        artistAttr.isOptional = true
        
        let albumAttr = NSAttributeDescription()
        albumAttr.name = "album"
        albumAttr.attributeType = .stringAttributeType
        albumAttr.isOptional = true
        
        let trackNumAttr = NSAttributeDescription()
        trackNumAttr.name = "trackNumber"
        trackNumAttr.attributeType = .integer32AttributeType
        trackNumAttr.isOptional = true
        
        let yearAttr = NSAttributeDescription()
        yearAttr.name = "year"
        yearAttr.attributeType = .integer32AttributeType
        yearAttr.isOptional = true
        
        let genreAttr = NSAttributeDescription()
        genreAttr.name = "genre"
        genreAttr.attributeType = .stringAttributeType
        genreAttr.isOptional = true
        
        let durationAttr = NSAttributeDescription()
        durationAttr.name = "duration"
        durationAttr.attributeType = .doubleAttributeType
        durationAttr.isOptional = false
        
        let bpmAttr = NSAttributeDescription()
        bpmAttr.name = "bpm"
        bpmAttr.attributeType = .doubleAttributeType
        bpmAttr.isOptional = true
        
        let keyAttr = NSAttributeDescription()
        keyAttr.name = "musicalKey"
        keyAttr.attributeType = .stringAttributeType
        keyAttr.isOptional = true
        
        let bitrateAttr = NSAttributeDescription()
        bitrateAttr.name = "bitrate"
        bitrateAttr.attributeType = .integer32AttributeType
        bitrateAttr.isOptional = true
        
        let sampleRateAttr = NSAttributeDescription()
        sampleRateAttr.name = "sampleRate"
        sampleRateAttr.attributeType = .doubleAttributeType
        sampleRateAttr.isOptional = true
        
        let channelsAttr = NSAttributeDescription()
        channelsAttr.name = "channels"
        channelsAttr.attributeType = .integer16AttributeType
        channelsAttr.isOptional = true
        
        let codecAttr = NSAttributeDescription()
        codecAttr.name = "codec"
        codecAttr.attributeType = .stringAttributeType
        codecAttr.isOptional = false

        // Full JSON-encoded AudioFile — the forward-compatible source of truth.
        // Legacy columns above are kept populated for external inspection only.
        let payloadAttr = NSAttributeDescription()
        payloadAttr.name = "payload"
        payloadAttr.attributeType = .binaryDataAttributeType
        payloadAttr.isOptional = true

        trackEntity.properties = [
            idAttr, urlAttr, bookmarkAttr,
            titleAttr, artistAttr, albumAttr, trackNumAttr, yearAttr, genreAttr,
            durationAttr, bpmAttr, keyAttr, bitrateAttr, sampleRateAttr, channelsAttr, codecAttr,
            payloadAttr
        ]
        
        model.entities = [trackEntity, bookmarkEntity]
        return model
    }
}

@objc(TrackEntity)
public class TrackEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var urlPath: String
    @NSManaged public var bookmarkData: Data?
    
    @NSManaged public var title: String?
    @NSManaged public var artist: String?
    @NSManaged public var album: String?
    @NSManaged public var trackNumber: NSNumber?
    @NSManaged public var year: NSNumber?
    @NSManaged public var genre: String?
    
    @NSManaged public var duration: Double
    @NSManaged public var bpm: NSNumber?
    @NSManaged public var musicalKey: String?
    @NSManaged public var bitrate: NSNumber?
    @NSManaged public var sampleRate: NSNumber?
    @NSManaged public var channels: NSNumber?
    @NSManaged public var codec: String
    @NSManaged public var payload: Data?
}

@objc(SourceBookmarkEntity)
public class SourceBookmarkEntity: NSManagedObject {
    @NSManaged public var bookmarkData: Data
}
