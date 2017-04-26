//
//  Created by Jesse Squires
//  http://www.hexedbits.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//
//
//  Converted to Swift by Tung Thanh Nguyen
//  Copyright © 2016 Tung Thanh Nguyen.
//  Released under an MIT license: http://opensource.org/licenses/MIT
//
//  GitHub
//  https://github.com/tungthanhnguyen/CSSystemSoundPlayer
//

import AudioToolbox
import Foundation

#if os(iOS)
	import UIKit
#endif

public let kCSSystemSoundPlayerUserDefaultsKey: String = "kCSSystemSoundPlayerUserDefaultsKey"

/**
 *  String constant for .caf audio file extension.
 */
public let kCSSystemSoundTypeCAF: String! = "caf"

/**
 *  String constant for .aif audio file extension.
 */
public let kCSSystemSoundTypeAIF: String! = "aif"

/**
 *  String constant for .aiff audio file extension.
 */
public let kCSSystemSoundTypeAIFF: String! = "aiff"

/**
 *  String constant for .wav audio file extension.
 */
public let kCSSystemSoundTypeWAV: String! = "wav"

/**
 *  A completion block to be called after a system sound has finished playing.
 */
public typealias CSSystemSoundPlayerCompletionBlock = () -> Void

////////////////////////////////////////////////////////////////////////////////
// Wrapper for sticking non-objects in NSDictionary instances
private class ObjectWrapper<T>
{
	public let value: T
	
	init(_ value: T)
	{
		self.value = value
	}
}
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
private func systemServicesSoundCompletion(soundID: SystemSoundID, data: UnsafeMutableRawPointer?)
{
	let player = CSSystemSoundPlayer.sharedPlayer
	
	let block: CSSystemSoundPlayerCompletionBlock? = player.completionBlockForSoundID(soundID)
	block!()
	player.removeCompletionBlockForSoundID(soundID)
}
////////////////////////////////////////////////////////////////////////////////


/**
 *  The `CSSystemSoundPlayer` class enables you to play sound effects, alert sounds, or other short sounds.
 *  It lazily loads and caches all `SystemSoundID` objects and purges them upon receiving the `UIApplicationDidReceiveMemoryWarningNotification` notification.
 */
open class CSSystemSoundPlayer: NSObject
{
	private var sounds: NSMutableDictionary!
	private var completionBlocks: NSMutableDictionary!
	
	/**
	 *  Returns whether or not the sound player is on.
	 *  That is, whether the sound player is enabled or disabled.
	 *  If disabled, it will not play sounds.
	 *
	 *  @see `toggleSoundPlayerOn:`
	 */
	public var isOn: Bool = false

	/**
	 * The bundle in which the sound player uses to search for sound file resources. You may change this property as needed.
	 * The default value is the main bundle. This value must not be `nil`.
	 */
	private var priBundle: Bundle? = nil
	public var bundle: Bundle?
	{
		get { return self.priBundle }
		set
		{
			if newValue != nil { self.priBundle = newValue }
		}
	}

	//////////////////////////////////////////////////////////////////////////////
	// MARK: - Init
	
	/**
	 * Returns the shared `CSSystemSoundPlayer` object. This property always returns the same sound system player object.
	 *
	 * @return An initialized `CSSystemSoundPlayer` object if successful, `nil` otherwise.
	 *
	 * @warning Completion blocks are only called for sounds played with the shared player.
	 */
	open static let sharedPlayer = CSSystemSoundPlayer()

	override public init()
	{
		super.init()

		initWithBundle(Bundle.main)
	}

	/**
	 * Returns a new `CSSystemSoundPlayer` instance with the specified bundle.
	 *
	 * @param bundle  The bundle in which the sound player uses to search for sound file resources.
	 *
	 * @return An initialized `CSSystemSoundPlayer` object.
	 *
	 * @warning Completion blocks are only called for sounds played with the shared player.
	 */
	internal func initWithBundle(_ bundle: Bundle)
	{
		self.bundle = bundle
		self.isOn = readSoundPlayerOnFromUserDefaults()
		self.sounds = NSMutableDictionary.init()
		self.completionBlocks = NSMutableDictionary.init()

#if os(iOS)
		NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveMemoryWarningNotification(_:)), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
#endif
	}
	
	deinit
	{
		unloadSoundIDs()
		
		self.sounds.removeAllObjects()
		self.sounds = nil
		
		self.completionBlocks.removeAllObjects()
		self.completionBlocks = nil
		
		NotificationCenter.default.removeObserver(self)
	}
	//////////////////////////////////////////////////////////////////////////////
	
	//////////////////////////////////////////////////////////////////////////////
	// MARK: - Playing sounds

	private func playSoundWith(pathToFile filePath: String, isAlert: Bool, completionBlock completion: CSSystemSoundPlayerCompletionBlock)
	{
		if (!self.isOn || filePath.isEmpty) { return }

		if sounds.object(forKey: filePath) == nil
		{
			addSoundIDForAudioFileWith(path: filePath)
		}

		playSoundWith(file: filePath, isAlert: isAlert, completionBlock: completion)
	}
	
	private func playSoundWith(fileName filename: String, extension ext: String, isAlert: Bool, completionBlock completion: CSSystemSoundPlayerCompletionBlock)
	{
		if !self.isOn { return }
		
		if filename.isEmpty || ext.isEmpty
		{
			return
		}
		
		if sounds.object(forKey: filename) == nil
		{
			addSoundIDForAudioFileWith(filename, extension: ext)
		}
		
		playSoundWith(file: filename, isAlert: isAlert, completionBlock: completion)
	}

	private func playSoundWith(file fileKey: String, isAlert: Bool, completionBlock completion: CSSystemSoundPlayerCompletionBlock)
	{
		let soundID: SystemSoundID = soundIDFor(file: fileKey)
		if soundID != 0
		{
			if completionBlocks != nil
			{
				let error: OSStatus = AudioServicesAddSystemSoundCompletion(soundID, nil, nil, systemServicesSoundCompletion, nil)
				if error != 0
				{
					logError(error, withMessage: "Warning! Completion block could not be added to SystemSoundID.")
				}
				else
				{
					addCompletionBlock(completion, toSoundID: soundID)
				}
			}

			if isAlert
			{
				AudioServicesPlayAlertSound(soundID)
			}
			else
			{
				AudioServicesPlaySystemSound(soundID)
			}
		}
	}
	
	private func readSoundPlayerOnFromUserDefaults() -> Bool
	{
		let setting = UserDefaults.standard.object(forKey: kCSSystemSoundPlayerUserDefaultsKey)
		if setting == nil
		{
			toggleSoundPlayerOn(true)
			return true
		}
		return (setting as! NSNumber).boolValue
	}
	//////////////////////////////////////////////////////////////////////////////
	
	//////////////////////////////////////////////////////////////////////////////
	// MARK: - Public API
	
	/**
	 *  Toggles the sound player on or off by setting the `SystemSoundPlayerUserDefaultsKey` key in `NSUserDefaults` to the given value.
	 *  This will enable or disable the playing of sounds via `SystemSoundPlayer` globally.
	 *  This setting is persisted across application launches.
	 *
	 *  @param on A boolean indicating whether or not to enable or disable the sound player settings. Pass `true` to turn sounds on, and `false` to turn sounds off.
	 *
	 *  @warning Disabling the sound player (passing a value of `false`) will invoke the `stopAllSounds` method.
	 */
	public func toggleSoundPlayerOn(_ isOn: Bool)
	{
		self.isOn = isOn
		
		let userDefaults = UserDefaults.standard
		userDefaults.set(self.isOn, forKey: kCSSystemSoundPlayerUserDefaultsKey)
		userDefaults.synchronize()
		
		if !self.isOn { stopAllSounds() }
	}

	/**
	 *  Plays a system sound object corresponding to an audio file with the given filename and extension.
	 *  The system sound player will lazily initialize and load the file before playing it, and then cache its corresponding `SystemSoundID`.
	 *  If this file has previously been played, it will be loaded from cache and played immediately.
	 *
	 *  @param filePath   A string containing full path of the audio file to play.
	 *
	 *  @warning If the system sound object cannot be created, this method does nothing.
	 */
	public func playSoundWith(pathToFile filePath: String)
	{
		playSoundWith(pathToFile: filePath, completionBlock: {})
	}

	/**
	 *  Plays a system sound object corresponding to an audio file with the given filename and extension, and excutes completionBlock when the sound has stopped playing.
	 *  The system sound player will lazily initialize and load the file before playing it, and then cache its corresponding `SystemSoundID`.
	 *  If this file has previously been played, it will be loaded from cache and played immediately.
	 *
	 *  @param filePath         A string containing full path of the audio file to play.
	 *
	 *  @param completionBlock  A block called after the sound has stopped playing.
	 *  This block is retained by `CSSystemSoundPlayer`, temporarily cached, and released after its execution.
	 *
	 *  @warning If the system sound object cannot be created, this method does nothing.
	 */
	public func playSoundWith(pathToFile filePath: String, completionBlock completion: CSSystemSoundPlayerCompletionBlock)
	{
		playSoundWith(pathToFile: filePath, isAlert: false, completionBlock: completion)
	}

	/**
	 *  Plays a system sound object *as an alert* corresponding to an audio file with the given filename and extension.
	 *  The system sound player will lazily initialize and load the file before playing it, and then cache its corresponding `SystemSoundID`.
	 *  If this file has previously been played, it will be loaded from cache and played immediately.
	 *
	 *  @param filePath   A string containing full path of the audio file to play.
	 *
	 *  @warning If the system sound object cannot be created, this method does nothing.
	 *
	 *  @warning This method performs the same functions as `playSoundWith: pathToFile:`, with the excepion that, depending on the particular iOS device, this method may invoke vibration.
	 */
	public func playAlertSoundWith(pathToFile filePath: String)
	{
		playAlertSoundWith(pathToFile: filePath, completionBlock: {})
	}

	/**
	 *  Plays a system sound object *as an alert* corresponding to an audio file with the given filename and extension, and and excutes completionBlock when the sound has stopped playing.
	 *  The system sound player will lazily initialize and load the file before playing it, and then cache its corresponding `SystemSoundID`.
	 *  If this file has previously been played, it will be loaded from cache and played immediately.
	 *
	 *  @param filePath         A string containing the base name of the audio file to play.
	 *
	 *  @param completionBlock  A block called after the sound has stopped playing.
	 *  This block is retained by `CSSystemSoundPlayer`, temporarily cached, and released after its execution.
	 *
	 *  @warning If the system sound object cannot be created, this method does nothing.
	 *
	 *  @warning This method performs the same functions as `playSoundWith: filePath: completion:`, with the excepion that, depending on the particular iOS device, this method may invoke vibration.
	 */
	public func playAlertSoundWith(pathToFile filePath: String, completionBlock completion: CSSystemSoundPlayerCompletionBlock)
	{
		playSoundWith(pathToFile: filePath, isAlert: true, completionBlock: completion)
	}

	/**
	 *  Plays a system sound object corresponding to an audio file with the given filename and extension.
	 *  The system sound player will lazily initialize and load the file before playing it, and then cache its corresponding `SystemSoundID`.
	 *  If this file has previously been played, it will be loaded from cache and played immediately.
	 *
	 *  @param fileName   A string containing the base name of the audio file to play.
	 *
	 *  @param extension  A string containing the extension of the audio file to play.
	 *  This parameter must be one of `kCSSystemSoundTypeCAF`, `kCSSystemSoundTypeAIF`, `kCSSystemSoundTypeAIFF`, or `kCSSystemSoundTypeWAV`.
	 *
	 *  @warning If the system sound object cannot be created, this method does nothing.
	 */
	public func playSoundWith(fileName filename: String, extension ext: String)
	{
		playSoundWith(fileName: filename, extension: ext, completionBlock: {})
	}

	/**
	 *  Plays a system sound object corresponding to an audio file with the given filename and extension, and excutes completionBlock when the sound has stopped playing.
	 *  The system sound player will lazily initialize and load the file before playing it, and then cache its corresponding `SystemSoundID`.
	 *  If this file has previously been played, it will be loaded from cache and played immediately.
	 *
	 *  @param filename         A string containing the base name of the audio file to play.
	 *
	 *  @param extension        A string containing the extension of the audio file to play.
	 *  This parameter must be one of `kCSSystemSoundTypeCAF`, `kCSSystemSoundTypeAIF`, `kCSSystemSoundTypeAIFF`, or `kCSSystemSoundTypeWAV`.
	 *
	 *  @param completionBlock  A block called after the sound has stopped playing.
	 *  This block is retained by `CSSystemSoundPlayer`, temporarily cached, and released after its execution.
	 *
	 *  @warning If the system sound object cannot be created, this method does nothing.
	 */
	public func playSoundWith(fileName filename: String, extension ext: String, completionBlock completion: CSSystemSoundPlayerCompletionBlock)
	{
		playSoundWith(fileName: filename, extension: ext, isAlert: false, completionBlock: completion)
	}

	/**
	 *  Plays a system sound object *as an alert* corresponding to an audio file with the given filename and extension.
	 *  The system sound player will lazily initialize and load the file before playing it, and then cache its corresponding `SystemSoundID`.
	 *  If this file has previously been played, it will be loaded from cache and played immediately.
	 *
	 *  @param filename   A string containing the base name of the audio file to play.
	 *  @param extension  A string containing the extension of the audio file to play.
	 *  This parameter must be one of `kCSSystemSoundTypeCAF`, `kCSSystemSoundTypeAIF`, `kCSSystemSoundTypeAIFF`, or `kCSSystemSoundTypeWAV`.
	 *
	 *  @warning If the system sound object cannot be created, this method does nothing.
	 *
	 *  @warning This method performs the same functions as `playSoundWith: fileName: extension:`, with the excepion that, depending on the particular iOS device, this method may invoke vibration.
	 */
	public func playAlertSoundWith(fileName filename: String, extension ext: String)
	{
		playAlertSoundWith(fileName: filename, extension: ext, completionBlock: {})
	}

	/**
	 *  Plays a system sound object *as an alert* corresponding to an audio file with the given filename and extension, and and excutes completionBlock when the sound has stopped playing.
	 *  The system sound player will lazily initialize and load the file before playing it, and then cache its corresponding `SystemSoundID`.
	 *  If this file has previously been played, it will be loaded from cache and played immediately.
	 *
	 *  @param filename         A string containing the base name of the audio file to play.
	 *
	 *  @param extension        A string containing the extension of the audio file to play.
	 *  This parameter must be one of `kCSSystemSoundTypeCAF`, `kCSSystemSoundTypeAIF`, `kCSSystemSoundTypeAIFF`, or `kCSSystemSoundTypeWAV`.
	 *
	 *  @param completionBlock  A block called after the sound has stopped playing.
	 *  This block is retained by `CSSystemSoundPlayer`, temporarily cached, and released after its execution.
	 *
	 *  @warning If the system sound object cannot be created, this method does nothing.
	 *
	 *  @warning This method performs the same functions as `playSoundWith: fileName: extension: completion:`, with the excepion that, depending on the particular iOS device, this method may invoke vibration.
	 */
	public func playAlertSoundWith(fileName filename: String, extension ext: String, completionBlock completion: CSSystemSoundPlayerCompletionBlock)
	{
		playSoundWith(fileName: filename, extension: ext, isAlert: true, completionBlock: completion)
	}

	/**
	 *  On some iOS devices, you can call this method to invoke vibration.
	 *  On other iOS devices this functionaly is not available, and calling this method does nothing.
	 */
#if os(iOS)
	public func playVibrateSound()
	{
		if self.isOn { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
	}
#endif
	
	/**
	 *  Stops playing all sounds immediately.
	 *
	 *  @warning Any completion blocks attached to any currently playing sound will *not* be executed.
	 *  Also, calling this method will purge all `SystemSoundID` objects from cache, regardless of whether or not they were currently playing.
	 */
	public func stopAllSounds()
	{
		unloadSoundIDs()
	}
	
	/**
	 *  Stops playing the sound with the given filename immediately.
	 *
	 *  @param filename The filename of the sound to stop playing.
	 *
	 *  @warning If a completion block is attached to the given sound, it will *not* be executed.
	 *  Also, calling this method will purge the `SystemSoundID` object for this file from cache, regardless of whether or not it was currently playing.
	 */
	public func stopSoundWith(fileName: String)
	{
		let soundID: SystemSoundID = soundIDFor(file: fileName)
		let data: NSData = dataWithSoundID(soundID)
		
		unloadSoundIDFor(fileName: fileName)
		
		sounds.removeObject(forKey: fileName)
		completionBlocks.removeObject(forKey: data)
	}
	
	/**
	 *  Preloads a system sound object corresponding to an audio file with the given filename and extension.
	 *  The system sound player will initialize, load, and cache the corresponding `SystemSoundID`.
	 *
	 *  @param filename   A string containing the base name of the audio file to play.
	 *  @param extension  A string containing the extension of the audio file to play.
	 *  This parameter must be one of `kCSSystemSoundTypeCAF`, `kCSSystemSoundTypeAIF`, `kCSSystemSoundTypeAIFF`, or `kCSSystemSoundTypeWAV`.
	 */
	public func preloadSoundWith(filename: String, extension ext: String)
	{
		if sounds.object(forKey: filename) != nil
		{
			addSoundIDForAudioFileWith(filename, extension: ext)
		}
	}
	//////////////////////////////////////////////////////////////////////////////
	
	//////////////////////////////////////////////////////////////////////////////
	// MARK: - Sound data
	
	private func dataWithSoundID(_ soundID: SystemSoundID) -> NSData
	{
		var _soundID = soundID
		return NSData(bytes: &_soundID, length: MemoryLayout<SystemSoundID>.size)
	}
	
	private func soundIDFromData(_ data: NSData) -> SystemSoundID
	{
		if data.length > 0
		{
			var soundID: SystemSoundID = 0
			data.getBytes(&soundID, length: MemoryLayout<SystemSoundID>.size)
			return soundID
		}
		
		return 0
	}
	//////////////////////////////////////////////////////////////////////////////
	
	//////////////////////////////////////////////////////////////////////////////
	// MARK: - Sound files
	
	private func soundIDFor(file fileKey: String) -> SystemSoundID
	{
		let soundData: NSData = self.sounds.object(forKey: fileKey) as! NSData
		return soundIDFromData(soundData)
	}

	private func addSoundIDForAudioFileWith(path filePath: String)
	{
		let soundID: SystemSoundID = createSoundIDWith(pathToFile: filePath)
		if soundID != 0
		{
			let data: NSData = dataWithSoundID(soundID)
			sounds.setObject(data, forKey: filePath as NSCopying)
		}
	}
	
	private func addSoundIDForAudioFileWith(_ filename: String, extension ext: String)
	{
		let soundID: SystemSoundID = createSoundIDWith(fileName: filename, extension: ext)
		if soundID != 0
		{
			let data: NSData = dataWithSoundID(soundID)
			sounds.setObject(data, forKey: filename as NSCopying)
		}
	}
	//////////////////////////////////////////////////////////////////////////////
	
	//////////////////////////////////////////////////////////////////////////////
	// MARK: - Sound completion blocks
	
	internal func completionBlockForSoundID(_ soundID: SystemSoundID) -> CSSystemSoundPlayerCompletionBlock
	{
		let data: NSData = dataWithSoundID(soundID)
		let objectWrapper: ObjectWrapper<CSSystemSoundPlayerCompletionBlock> = completionBlocks.object(forKey: data) as! ObjectWrapper<CSSystemSoundPlayerCompletionBlock>
		return objectWrapper.value
	}
	
	private func addCompletionBlock(_ block: CSSystemSoundPlayerCompletionBlock, toSoundID soundID: SystemSoundID)
	{
		let data: NSData = dataWithSoundID(soundID)
		completionBlocks.setObject(ObjectWrapper(block), forKey: data)
	}
	
	internal func removeCompletionBlockForSoundID(_ soundID: SystemSoundID)
	{
		let key: NSData = dataWithSoundID(soundID)
		completionBlocks.removeObject(forKey: key)
		AudioServicesRemoveSystemSoundCompletion(soundID)
	}
	//////////////////////////////////////////////////////////////////////////////
	
	//////////////////////////////////////////////////////////////////////////////
	// MARK: - Managing sounds

	private func createSoundIDWith(pathToFile path: String) -> SystemSoundID
	{
		return createSoundIDWith(fileURL: URL(string: path)!)
	}
	
	private func createSoundIDWith(fileName filename: String, extension ext: String) -> SystemSoundID
	{
		let fileURL: URL = self.bundle!.url(forResource: filename, withExtension: ext)!

		return createSoundIDWith(fileURL: fileURL)
	}

	private func createSoundIDWith(fileURL: URL) -> SystemSoundID
	{
		if FileManager.default.fileExists(atPath: fileURL.path)
		{
			var soundID: SystemSoundID = 0;
			let error: OSStatus = AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
			if error != 0
			{
				self.logError(error, withMessage: "Warning! SystemSoundID could not be created.")
				return 0;
			}
			else { return soundID }
		}

		NSLog("\(self) Error: audio file not found at URL: \(fileURL)")
		return 0
	}
	
	private func unloadSoundIDs()
	{
		for eachFilename in self.sounds.allKeys
		{
			unloadSoundIDFor(fileName: eachFilename as! String)
		}
		
		sounds.removeAllObjects()
		completionBlocks.removeAllObjects()
	}
	
	private func unloadSoundIDFor(fileName filename: String)
	{
		let soundID: SystemSoundID = soundIDFor(file: filename)
		if soundID != 0
		{
			AudioServicesRemoveSystemSoundCompletion(soundID)
			let error: OSStatus = AudioServicesDisposeSystemSoundID(soundID)
			if error != 0
			{
				logError(error, withMessage: "Warning! SystemSoundID could not be disposed.")
			}
		}
	}
	
	private func logError(_ error: OSStatus, withMessage message: String)
	{
		var errorMessage: String = ""
		
		switch error
		{
		case kAudioServicesUnsupportedPropertyError:
			errorMessage = "The property is not supported."

		case kAudioServicesBadPropertySizeError:
			errorMessage = "The size of the property data was not correct."

		case kAudioServicesBadSpecifierSizeError:
			errorMessage = "The size of the specifier data was not correct."

		case kAudioServicesSystemSoundUnspecifiedError:
			errorMessage = "An unspecified error has occurred."

		case kAudioServicesSystemSoundClientTimedOutError:
			errorMessage = "System sound client message timed out."

		default:
			break
		}
		
		NSLog("\(self) \(message) Error: (code \(error.bigEndian)) \(errorMessage)")
	}
	//////////////////////////////////////////////////////////////////////////////
	
	//////////////////////////////////////////////////////////////////////////////
	// MARK: - Notifications
	
	internal func didReceiveMemoryWarningNotification(_ notification: NSNotification)
	{
		unloadSoundIDs()
	}
	//////////////////////////////////////////////////////////////////////////////
}
